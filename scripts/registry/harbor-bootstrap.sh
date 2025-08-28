#!/usr/bin/env bash
# Harbor bootstrap
# Modes:
#   - no args        : ensure project (+auto-scan), create robot, emit K8s pull secret (if new), and local login/logout scripts
#   - create-robot   : ensure project exists, create robot, emit secret (if new), and login/logout scripts
#
# Requires: curl, jq, base64
# Env:
#   See env-vars.sh example at the end of this file header.

set -euo pipefail

[ -f ./env-vars.sh ] && . ./env-vars.sh

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }
need curl; need jq; need base64

# ---------- Config from env ----------
req_common="HARBOR_HOST HARBOR_USERNAME HARBOR_PASSWORD PROJECT_NAME ROBOT_NAME ROBOT_ACTIONS ROBOT_DURATION"
for v in $req_common; do [ -n "${!v:-}" ] || { echo "Missing env var: $v"; exit 1; }; done

# Optional (with defaults)
PROJECT_PUBLIC="${PROJECT_PUBLIC:-false}"
PROJECT_AUTO_SCAN="${PROJECT_AUTO_SCAN:-true}"
NAMESPACE="${NAMESPACE:-default}"
SECRET_NAME="${SECRET_NAME:-harbor-creds}"
DOCKER_EMAIL="${DOCKER_EMAIL:-noreply@example.com}"
VERIFY_TLS="${HARBOR_VERIFY_TLS:-true}"

# Output directory for rendered files (K8s secret + login/logout scripts)
OUTPUT_DIR="${OUTPUT_DIR:-${HOME}/tmp}"
mkdir -p "${OUTPUT_DIR}"

tolower(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

curl_flags="-sS -H Accept:application/json"
[ "$(tolower "$VERIFY_TLS")" = "true" ] || curl_flags="$curl_flags -k"

api(){
  local m p d; m="$1"; p="$2"; shift 2; d="${1-}"
  if [ -n "$d" ]; then
    # shellcheck disable=SC2086
    curl $curl_flags -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
      -H "Content-Type: application/json" -X "$m" -d "$d" \
      "https://${HARBOR_HOST}/api/v2.0${p}"
  else
    # shellcheck disable=SC2086
    curl $curl_flags -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
      -X "$m" "https://${HARBOR_HOST}/api/v2.0${p}"
  fi
}

api_with_status(){
  local m p d; m="$1"; p="$2"; shift 2; d="${1-}"
  if [ -n "$d" ]; then
    # shellcheck disable=SC2086
    curl $curl_flags -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
      -H "Content-Type: application/json" -X "$m" -d "$d" \
      -w '\n%{http_code}' "https://${HARBOR_HOST}/api/v2.0${p}"
  else
    # shellcheck disable=SC2086
    curl $curl_flags -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
      -X "$m" -w '\n%{http_code}' "https://${HARBOR_HOST}/api/v2.0${p}"
  fi
}

mk_repo_access(){
  local acts="$1" arr="[]"
  IFS=','; for a in $acts; do
    at="$(printf '%s' "$a" | tr -d ' ')"
    arr="$(jq --arg act "$at" '. + [{resource:"repository", action:$act}]' <<<"$arr")"
  done; unset IFS
  printf '%s' "$arr"
}

render_secret_yaml(){
  # $1 robot_fullname  $2 robot_token
  local user="$1" token="$2"
  local auth json b64json
  auth="$(printf '%s' "${user}:${token}" | base64)"
  json="$(cat <<EOF
{"auths":{"${HARBOR_HOST}":{"username":"${user}","password":"${token}","email":"${DOCKER_EMAIL}","auth":"${auth}"}}}
EOF
)"
  b64json="$(printf '%s' "$json" | base64 | tr -d '\n')"
  cat <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ${b64json}
EOF
}

# Emit local login/logout helper scripts
emit_login_logout_scripts(){
  # $1 robot_fullname  $2 robot_token (may be empty if robot existed)
  local user="$1" token="${2-}"
  local login="${OUTPUT_DIR}/harbor-login.sh"
  local logout="${OUTPUT_DIR}/harbor-logout.sh"
  local envf="${OUTPUT_DIR}/harbor-auth.env"

  # helper to single-quote safely for bash env files: 'abc' -> 'a'\''bc'
  sq() { printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"; }

  # write/refresh env file (never echo token to stdout)
  {
    echo "# Harbor auth (generated)"
    echo "HARBOR_HOST=$(sq "${HARBOR_HOST}")"
    echo "HARBOR_USER=$(sq "${user}")"
    if [ -n "$token" ]; then
      echo "HARBOR_TOKEN=$(sq "${token}")"
    else
      # keep previous token if present; otherwise leave undefined
      echo "# HARBOR_TOKEN is not stored because Harbor did not return it for existing robot."
    fi
  } > "${envf}"

  # login script: uses --password-stdin and sources env file
  cat >"$login" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "${DIR}/harbor-auth.env"

: "${HARBOR_HOST:?missing HARBOR_HOST in harbor-auth.env}"
: "${HARBOR_USER:?missing HARBOR_USER in harbor-auth.env}"

if [ -z "${HARBOR_TOKEN:-}" ]; then
  read -r -s -p "Token for ${HARBOR_USER} @ ${HARBOR_HOST}: " HARBOR_TOKEN
  echo
fi

# Docker
printf '%s' "$HARBOR_TOKEN" | docker login "$HARBOR_HOST" -u "$HARBOR_USER" --password-stdin

# Helm (optional)
if command -v helm >/dev/null 2>&1; then
  # helm doesn't support --password-stdin; pass via env to avoid shell interpolation issues
  HELM_REGISTRY_CONFIG="${DIR}/.helmconfig.json" \
  HELM_EXPERIMENTAL_OCI=1 \
  helm registry login "$HARBOR_HOST" -u "$HARBOR_USER" -p "$HARBOR_TOKEN"
fi

echo "Logged in to ${HARBOR_HOST} as ${HARBOR_USER}"
EOF

  # logout script
  cat >"$logout" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "${DIR}/harbor-auth.env"

: "${HARBOR_HOST:?missing HARBOR_HOST in harbor-auth.env}"

# docker next
docker logout "$HARBOR_HOST" >/dev/null 2>&1 || true

# helm last
if command -v helm >/dev/null 2>&1; then
  helm registry logout "$HARBOR_HOST" >/dev/null 2>&1 || true
fi

echo "Logged out of ${HARBOR_HOST}"
EOF


  chmod +x "$login" "$logout"

  echo "Local auth helpers:"
  echo "  ${login}"
  echo "  ${logout}"
  echo "Env file (edit/rotate here):"
  echo "  ${envf}"
}


detect_project_robot_ep(){
  local pid="$1" body_code code body
  body_code="$(api_with_status GET "/projects/${pid}/robots")"
  code="$(printf '%s' "$body_code" | tail -n1)"
  body="$(printf '%s' "$body_code" | sed '$d')"
  if [ "$code" = "200" ] && ! echo "$body" | jq -e '.errors[]?.code=="NOT_FOUND"' >/dev/null 2>&1; then
    echo "id"
  else
    echo "none"
  fi
}

create_system_robot(){
  # Tries NEW schema (kind/namespace + duration) then OLD (scope + duration)
  # 409 => treat as exists; return name (no secret)
  local sys_name="$1" name="" secret="" access_json perms body resp code first typ

  access_json="$(mk_repo_access "$ROBOT_ACTIONS")"

  # NEW schema
  perms="$(jq -n --arg ns "$PROJECT_NAME" --argjson acc "$access_json" \
    '[{kind:"project", namespace:$ns, access:$acc}]')"
  body="$(jq -n --arg name "$sys_name" --arg desc "System robot scoped to project '"$PROJECT_NAME"'" \
    --argjson dur $ROBOT_DURATION --argjson perms "$perms" \
    '{name:$name, description:$desc, level:"system", duration:$dur, permissions:$perms}')"
  resp="$(api_with_status POST "/robots" "$body" || true)"
  code="$(printf '%s' "$resp" | tail -n1)"
  first="$(printf '%s' "$resp" | sed '$d')"

  if [ "$code" = "201" ] || [ "$code" = "200" ]; then
    typ="$(echo "$first" | jq -r 'type' 2>/dev/null || echo "")"
    [ "$typ" = "array" ] && first="$(echo "$first" | jq '.[0]')"
    name="$(echo "$first" | jq -r '.name // empty' 2>/dev/null || echo "")"
    secret="$(echo "$first" | jq -r '.secret // empty' 2>/dev/null || echo "")"
    printf '%s\n%s\n' "$name" "$secret"; return 0
  fi
  if [ "$code" = "409" ] && echo "$first" | grep -qi 'already exists'; then
    printf 'robot$%s\n\n' "$sys_name"; return 0
  fi

  # OLD schema
  local scope perm_old body_old resp_old code_old first_old
  scope="/project/${pid}"
  perm_old="$(jq -n --arg sc "$scope" --argjson acc "$access_json" '{scope:$sc, access:$acc}')"
  body_old="$(jq -n --arg name "$sys_name" --arg desc "System robot scoped to project '"$PROJECT_NAME"'" \
    --argjson dur $ROBOT_DURATION --argjson po "$perm_old" \
    '{name:$name, description:$desc, level:"system", duration:$dur, permissions:[$po]}')"
  resp_old="$(api_with_status POST "/robots" "$body_old" || true)"
  code_old="$(printf '%s' "$resp_old" | tail -n1)"
  first_old="$(printf '%s' "$resp_old" | sed '$d')"

  if [ "$code_old" = "201" ] || [ "$code_old" = "200" ]; then
    typ="$(echo "$first_old" | jq -r 'type' 2>/dev/null || echo "")"
    [ "$typ" = "array" ] && first_old="$(echo "$first_old" | jq '.[0]')"
    name="$(echo "$first_old" | jq -r '.name // empty' 2>/dev/null || echo "")"
    secret="$(echo "$first_old" | jq -r '.secret // empty' 2>/dev/null || echo "")"
    printf '%s\n%s\n' "$name" "$secret"; return 0
  fi
  if [ "$code_old" = "409" ] && echo "$first_old" | grep -qi 'already exists'; then
    printf 'robot$%s\n\n' "$sys_name"; return 0
  fi

  echo "Create system robot failed. NEW(code=$code) OLD(code=$code_old)" 1>&2
  echo "NEW body:" 1>&2; printf '%s\n' "$first" 1>&2
  echo "OLD body:" 1>&2; printf '%s\n' "$first_old" 1>&2
  return 1
}

usage(){
  cat <<EOF
Usage:
  $(basename "$0")             # ensure project, create robot, emit secret (if new), login/logout scripts
  $(basename "$0") create-robot# create robot only, emit secret (if new), login/logout scripts. Project must exist.

Env (via env-vars.sh):
  HARBOR_HOST, HARBOR_USERNAME, HARBOR_PASSWORD
  PROJECT_NAME, PROJECT_PUBLIC (default: false), PROJECT_AUTO_SCAN (default: true)
  ROBOT_NAME, ROBOT_ACTIONS (e.g., "push,pull"), ROBOT_DURATION (-1 = never)
  SECRET_NAME (default: harbor-creds), NAMESPACE (default: default), DOCKER_EMAIL (optional)
  OUTPUT_DIR (default: \$HOME/tmp)
EOF
}

mode="${1:-all}"
if [ "$mode" != "all" ] && [ "$mode" != "create-robot" ]; then usage; exit 2; fi

# ---------- 0) auth smoke ----------
api GET "/users/current" >/dev/null || { echo "Auth failed. Check HARBOR_* envs."; exit 1; }

# ---------- 1) ensure/find project ----------
pj="$(api GET "/projects?name=${PROJECT_NAME}")"
if [ "$(echo "$pj" | jq 'length')" -gt 0 ]; then
  pid="$(echo "$pj" | jq -r '.[0].project_id')"
  echo "Project '${PROJECT_NAME}' exists (id=${pid})."
else
  if [ "$mode" = "create-robot" ]; then
    echo "Project '${PROJECT_NAME}' not found, and mode=create-robot will not create it. Aborting."
    exit 1
  fi
  echo "Creating project '${PROJECT_NAME}' (public=${PROJECT_PUBLIC}, auto_scan=${PROJECT_AUTO_SCAN})..."
  body="$(jq -n --arg n "$PROJECT_NAME" --arg pub "$PROJECT_PUBLIC" --arg as "$PROJECT_AUTO_SCAN" '
    {
      project_name: $n,
      public: (if $pub=="true" then true else false end),
      metadata: {
        public: $pub,
        auto_scan: (if $as=="true" then "true" else "false" end),
        reuse_sys_cve_allowlist: "true"
      }
    }')"
  api POST "/projects" "$body" >/dev/null || true
  pj="$(api GET "/projects?name=${PROJECT_NAME}")"
  pid="$(echo "$pj" | jq -r '.[0].project_id')"
  [ -n "$pid" ] && [ "$pid" != "null" ] || { echo "Failed to get project_id"; exit 1; }
  echo "Created project id=${pid}."
fi

# ---------- 1a) project metadata (only in 'all' mode) ----------
if [ "$mode" = "all" ]; then
  if [ "$(tolower "$PROJECT_AUTO_SCAN")" = "true" ]; then
    api PUT "/projects/${pid}/metadatas/auto_scan" '{"value":"true"}' >/dev/null || true
  else
    api PUT "/projects/${pid}/metadatas/auto_scan" '{"value":"false"}' >/dev/null || true
  fi
fi

# ---------- 2) robots endpoint choice ----------
ep="$(detect_project_robot_ep "$pid")"

robot_fullname=""; robot_secret=""; created="false"

if [ "$ep" = "id" ]; then
  echo "Using endpoint: /projects/{id}/robots"
  rb="$(api GET "/projects/${pid}/robots")"
  robot_fullname="$(
    echo "$rb" | jq -r --arg rn "$ROBOT_NAME" '
      (.. | objects | select(has("name")) | .name)
      | select(test("\\$[A-Za-z0-9_-]+\\+" + $rn + "$"))
    ' | head -n1
  )"
  if [ -n "$robot_fullname" ]; then
    echo "Project robot '${robot_fullname}' already exists."
  else
    echo "Creating project robot '${ROBOT_NAME}' (duration=${ROBOT_DURATION})…"
    access="[]"; IFS=','; for a in $ROBOT_ACTIONS; do at="$(printf '%s' "$a" | tr -d ' ')"; access="$(jq --arg id "$pid" --arg act "$at" '. + [{resource: ("/project/" + $id + "/repository"), action:$act}]' <<<"$access")"; done; unset IFS
    body="$(jq -n --arg name "$ROBOT_NAME" --arg desc "Robot for ${PROJECT_NAME}" --argjson dur $ROBOT_DURATION --argjson access "$access" \
      '{name:$name, description:$desc, duration:$dur, access:$access}')"
    cr="$(api_with_status POST "/projects/${pid}/robots" "$body" || true)"
    code="$(printf '%s' "$cr" | tail -n1)"
    content="$(printf '%s' "$cr" | sed '$d')"
    if [ "$code" = "201" ] || [ "$code" = "200" ]; then
      robot_fullname="$(echo "$content" | jq -r '.name // empty' 2>/dev/null || echo "")"
      robot_secret="$(echo "$content" | jq -r '.secret // empty' 2>/dev/null || echo "")"
      created="true"
    elif [ "$code" = "409" ] && echo "$content" | grep -qi 'already exists'; then
      rb="$(api GET "/projects/${pid}/robots")"
      robot_fullname="$(
        echo "$rb" | jq -r --arg rn "$ROBOT_NAME" '
          (.. | objects | select(has("name")) | .name)
          | select(test("\\$[A-Za-z0-9_-]+\\+" + $rn + "$"))
        ' | head -n1
      )"
      created="false"
    else
      echo "Project robot create failed (HTTP $code). Body:" 1>&2
      printf '%s\n' "$content" 1>&2
      exit 1
    fi
  fi
else
  echo "Project robots API not present => using SYSTEM robots API with scoped permissions."
  sys_name="${PROJECT_NAME}-${ROBOT_NAME}"
  ex="$(api GET "/robots?q=name%3D${sys_name}" || true)"
  robot_fullname="$(
    echo "$ex" | jq -r --arg n "robot$${sys_name}" '
      (.. | objects | select(has("name")) | .name) | select(.==$n)
    ' | head -n1
  )"
  if [ -n "$robot_fullname" ]; then
    echo "System robot '${robot_fullname}' already exists."
  else
    echo "Creating SYSTEM robot '${sys_name}' (duration=${ROBOT_DURATION})…"
    set +e
    out="$(create_system_robot "$sys_name" 2>&1)"
    rc=$?
    set -e
    if [ $rc -ne 0 ]; then
      echo "$out" 1>&2
      echo "System robot creation failed after schema attempts."
      exit 1
    fi
    robot_fullname="$(printf '%s' "$out" | sed -n '1p')"
    robot_secret="$(printf '%s' "$out" | sed -n '2p')"
    created="true"
  fi
fi

# ---------- 3) Output + File emission ----------
echo
echo "================== RESULT =================="
echo "Harbor:      https://${HARBOR_HOST}"
echo "Project:     ${PROJECT_NAME} (id=${pid})"
vis="private"; [ "$(tolower "$PROJECT_PUBLIC")" = "true" ] && vis="public"
echo "Visibility:  ${vis}"
echo "Robot user:  ${robot_fullname:-<unknown>}"

# Always emit logout; emit login with token if we have it, otherwise prompt-based
emit_login_logout_scripts "${robot_fullname}" "${robot_secret:-}"

if [ "$created" = "true" ] && [ -n "${robot_secret:-}" ]; then
  echo "Robot token: ${robot_secret}"
  out_file="${OUTPUT_DIR}/${SECRET_NAME}.yaml"
  render_secret_yaml "${robot_fullname}" "${robot_secret}" > "${out_file}"
  echo
  echo "Kubernetes pull secret rendered -> ${out_file}"
  echo "Apply with:"
  echo "  kubectl apply -n ${NAMESPACE} -f ${out_file}"
elif [ -n "${robot_fullname:-}" ]; then
  echo "Robot token: <NOT SHOWN> (existing robot; Harbor will not re-show the secret)"
  echo "Login helper will prompt for token if needed:"
  echo "  ${OUTPUT_DIR}/harbor-login.sh"
else
  echo "Robot not created or found — check logs above."
  exit 1
fi
echo "==========================================="
