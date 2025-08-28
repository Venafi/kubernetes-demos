#!/usr/bin/env bash
# Offline generator for per-chart values files that set image.repository (and image.tag when provided in charts.txt).
# - Reads charts.txt + component-versions.sh
# - Emits only known/declared image keys per chart (built-in + user-extensible via values-mapping.txt)

#
# Usage:
#   ./generate-helm-values.sh --outdir ~/tmp/my-values
#
# Env config (in env-mirror.sh or env):
#   DST_REGISTRY, DST_PROJECT, DST_SUFFIX ("" allowed)
#   EMIT_TAGS: auto|always|never  (default auto)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OUTDIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --outdir) OUTDIR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "${OUTDIR}" ] && { echo "ERROR: --outdir is required" >&2; exit 2; }
mkdir -p "${OUTDIR}"

# Load env/config
[ -f "${SCRIPT_DIR}/env-mirror.sh" ] && . "${SCRIPT_DIR}/env-mirror.sh"
[ -f "${SCRIPT_DIR}/component-versions.sh" ] && . "${SCRIPT_DIR}/component-versions.sh"

: "${DST_REGISTRY:?DST_REGISTRY is required}"
: "${DST_PROJECT:?DST_PROJECT is required}"
: "${DST_SUFFIX:=}"
: "${EMIT_TAGS:=auto}"  # auto|always|never

CHARTS_FILE="${SOURCE_LIST:-${SCRIPT_DIR}/charts.txt}"
MAP_FILE="${SCRIPT_DIR}/values-mapping.txt"   # optional user overrides

expand_vars(){ eval "echo \"$1\""; }

with_suffix_last(){
  local path="$1" suffix="${DST_SUFFIX:-}"
  [ -z "$suffix" ] && { printf '%s' "$path"; return; }
  local base="${path##*/}" parent="${path%/*}"
  [ "$parent" = "$path" ] && { printf '%s%s' "$path" "$suffix"; return; }
  printf '%s/%s%s' "$parent" "$base" "$suffix"
}

# Split host/path[:tag] -> "nohost;tag"
split_nohost_and_tag(){
  local full="$1" path tag=""
  path="${full#*/}"
  if printf '%s' "$path" | grep -q ':'; then
    tag="${path##*:}"
    path="${path%:${tag}}"
  fi
  printf '%s;%s' "$path" "$tag"
}

# Pick image by token (in last path segment). Returns "nohost;tag".
pick_img_by_token(){
  local token="$1"; shift
  local first_path=""; local first_tag=""
  while [ $# -gt 0 ]; do
    local img="$1"; shift
    local parts; parts="$(split_nohost_and_tag "$img")"
    local nohost="${parts%%;*}"; local tag="${parts##*;}"
    [ -z "$first_path" ] && { first_path="$nohost"; first_tag="$tag"; }
    local last="${nohost##*/}"
    echo "$last" | grep -qi -- "$token" && { printf '%s;%s' "$nohost" "$tag"; return 0; }
  done
  [ -n "$first_path" ] && { printf '%s;%s' "$first_path" "$first_tag"; return 0; }
  return 1
}

mk_dst_repo(){
  local chosen_nohost="$1"
  printf '%s/%s/%s' "$DST_REGISTRY" "$DST_PROJECT" "$chosen_nohost"
}

# Emit dot-path repo (+ optional tag)
emit_repo_kv(){
  # $1 dot path (e.g., "image.repository" or "webhook.image.repository")
  # $2 dst_repo, $3 dst_tag (may be empty), $4 out_file
  local path="$1" repo="$2" tag="$3" out="$4"
  IFS='.' read -r p1 p2 p3 <<< "$path"
  if [ -n "$p3" ]; then
    cat >> "$out" <<EOF
${p1}:
  ${p2}:
    repository: ${repo}
EOF
    if [ "$EMIT_TAGS" = "always" ] && [ -n "${CHART_VER:-}" ] && [ -z "$tag" ]; then
      echo "    tag: ${CHART_VER}" >> "$out"
    elif [ "$EMIT_TAGS" = "auto" ] && [ -n "$tag" ]; then
      echo "    tag: ${tag}" >> "$out"
    fi
  elif [ -n "$p2" ]; then
    cat >> "$out" <<EOF
${p1}:
  repository: ${repo}
EOF
    if [ "$EMIT_TAGS" = "always" ] && [ -n "${CHART_VER:-}" ] && [ -z "$tag" ]; then
      echo "  tag: ${CHART_VER}" >> "$out"
    elif [ "$EMIT_TAGS" = "auto" ] && [ -n "$tag" ]; then
      echo "  tag: ${tag}" >> "$out"
    fi
  else
    cat >> "$out" <<EOF
image:
  repository: ${repo}
EOF
    if [ "$EMIT_TAGS" = "always" ] && [ -n "${CHART_VER:-}" ] && [ -z "$tag" ]; then
      echo "  tag: ${CHART_VER}" >> "$out"
    elif [ "$EMIT_TAGS" = "auto" ] && [ -n "$tag" ]; then
      echo "  tag: ${tag}" >> "$out"
    fi
  fi
}

# ---------------- Built-in slot maps (generic) ----------------
# Each entry: "chart;dot.path;token"
builtin_map() {
  cat <<'EOF'
cert-manager;image.repository;controller
cert-manager;webhook.image.repository;webhook
cert-manager;cainjector.image.repository;cainjector
cert-manager;startupapicheck.image.repository;startupapicheck

cert-manager-csi-driver;image.repository;csi-driver
cert-manager-csi-driver;nodeDriverRegistrar.image.repository;registrar
cert-manager-csi-driver;livenessProbe.image.repository;liveness

cert-manager-csi-driver-spiffe;image.repository;spiffe
cert-manager-csi-driver-spiffe;approver.image.repository;approver

cert-manager-istio-csr;image.repository;istio-csr

# single-image charts (token same as chart or shortened)
cert-manager-approver-policy;image.repository;approver-policy
approver-policy-enterprise;image.repository;approver-policy-enterprise
trust-manager;image.repository;trust-manager
venafi-enhanced-issuer;image.repository;enhanced-issuer
openshift-routes;image.repository;openshift
venafi-kubernetes-agent;image.repository;agent
EOF
}

# Load maps: built-in + optional values-mapping.txt (same "chart;dot.path;token" format)
load_maps(){
  builtin_map
  if [ -f "$MAP_FILE" ]; then
    # allow comments and blanks
    grep -Ev '^\s*($|#)' "$MAP_FILE" || true
  fi
}

# Generate values for one chart using maps + images
gen_values_for_chart(){
  local chart="$1"; shift
  CHART_VER="$1"; shift
  local out="${OUTDIR}/${chart}-values.yaml"
  : > "$out"

  # Pull all rules for this chart
  local rules
  rules="$(load_maps | awk -F';' -v C="$chart" '{gsub(/^[ \t]+|[ \t]+$/, "", $1); if($1==C) print $0;}')"

  if [ -z "$rules" ]; then
    # Fallback: single-image charts -> best effort default
    if [ $# -gt 0 ]; then
      local parts; parts="$(split_nohost_and_tag "$1")"
      local p="${parts%%;*}"; local t="${parts##*;}"
      emit_repo_kv "image.repository" "$(mk_dst_repo "$p")" "$t" "$out"
      echo "[ok]  ${chart}: wrote ${out} (fallback single-image)"
    else
      echo "[skip] ${chart}: no image rules and no images"
      rm -f "$out"
    fi
    return 0
  fi

  # Apply each rule
  local wrote=0
  while IFS=';' read -r rchart rpath rtoken; do
    [ -z "$rchart" ] && continue
    # shellcheck disable=SC2124
    local chosen; chosen="$(pick_img_by_token "$rtoken" "$@")" || continue
    local p="${chosen%%;*}"; local t="${chosen##*;}"
    emit_repo_kv "$rpath" "$(mk_dst_repo "$p")" "$t" "$out"
    wrote=1
  done <<EOF
$rules
EOF

  if [ "$wrote" -eq 0 ]; then
    # As a last resort, if there are images, emit the first under image.repository
    if [ $# -gt 0 ]; then
      local parts; parts="$(split_nohost_and_tag "$1")"
      local p="${parts%%;*}"; local t="${parts##*;}"
      emit_repo_kv "image.repository" "$(mk_dst_repo "$p")" "$t" "$out"
      echo "[ok]  ${chart}: wrote ${out} (fallback)"
    else
      echo "[skip] ${chart}: no matching images for rules"
      rm -f "$out"
      return 0
    fi
  else
    echo "[ok]  ${chart}: wrote ${out}"
  fi
}

# ---------------- Parse charts.txt and run ----------------
current_chart=""; current_ver=""; images=()

flush_chart(){
  [ -z "${current_chart}" ] && return 0
  if [ "${#images[@]}" -gt 0 ] 2>/dev/null; then
    gen_values_for_chart "$current_chart" "$current_ver" "${images[@]}"
  else
    gen_values_for_chart "$current_chart" "$current_ver"
  fi
  images=()
}

while IFS= read -r raw; do
  line="$(expand_vars "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/\r$//')"
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac

  if printf '%s' "$line" | grep -q '^oci://'; then
    flush_chart
    ver="${line##*:}"
    repo="${line%:${ver}}"
    tmp="${repo#oci://}"; tmp="${tmp#*/charts/}"; chart_name="${tmp}"
    current_chart="$chart_name"
    current_ver="$ver"
  else
    images+=( "$line" )
  fi
done < "${CHARTS_FILE}"
flush_chart

echo "Done. Values files in: ${OUTDIR}"
