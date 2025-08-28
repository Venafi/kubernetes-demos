#!/usr/bin/env bash
# CCM (CyberArk Certificate Manager) components mirror
# - Mirrors Helm charts (OCI) and container images between registries
# - Supports: mirror (online src->dst), download (to tars), upload (from tars -> dst)
# Usage: ./ccm-components.sh [mirror|download|upload]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${SCRIPT_DIR}/env-mirror.sh" ] && . "${SCRIPT_DIR}/env-mirror.sh"
[ -f "${SCRIPT_DIR}/component-versions.sh" ] && . "${SCRIPT_DIR}/component-versions.sh"

MODE="${1:-${MODE:-mirror}}"
SOURCE_LIST="${SOURCE_LIST:-${SCRIPT_DIR}/charts.txt}"
WORKDIR="${WORKDIR:-${SCRIPT_DIR}/_work}"
mkdir -p "${WORKDIR}/charts" "${WORKDIR}/images"

# --- Preflight: ensure all ${VARS} in charts.txt are defined ---
missing=""
vars=$(grep -Eo '\$\{[A-Za-z0-9_]+\}' "$SOURCE_LIST" | sort -u || true)
for v in $vars; do
  name="${v#\$\{}"; name="${name%\}}"
  if [ -z "${!name:-}" ]; then
    missing="${missing} ${name}"
  fi
done
if [ -n "$missing" ]; then
  echo "FATAL: missing required variables:${missing}" >&2
  echo "Hint: ensure component-versions.sh is present/sourced or set them in env-mirror.sh." >&2
  exit 3
fi

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Missing '$1'"; exit 2; }; }
need helm; need skopeo

# TLS flags 
HELM_INSECURE_FLAGS=""
SKOPEO_SRC_TLS="--src-tls-verify=true"
SKOPEO_DST_TLS="--dest-tls-verify=true"
if [ "${INSECURE:-0}" = "1" ]; then
  HELM_INSECURE_FLAGS="--insecure"
  SKOPEO_SRC_TLS="--src-tls-verify=false"
  SKOPEO_DST_TLS="--dest-tls-verify=false"
fi

# Platform selection for skopeo
SKOPEO_PLAT_FLAGS=()
if [ "${COPY_ALL_PLATFORMS:-0}" = "1" ]; then
  SKOPEO_PLAT_FLAGS+=(--all)
elif [ -n "${PLATFORM:-}" ]; then
  # PLATFORM format: os/arch[/variant], e.g. linux/amd64 or linux/arm64/v8
  _plat_os="$(printf '%s' "$PLATFORM" | cut -d/ -f1)"
  _plat_arch="$(printf '%s' "$PLATFORM" | cut -d/ -f2)"
  _plat_var="$(printf '%s' "$PLATFORM" | cut -d/ -f3- | sed -e 's|^$||')"
  [ -n "${_plat_os}" ]   && SKOPEO_PLAT_FLAGS+=(--src-tls-verify=true --override-os "${_plat_os}")
  [ -n "${_plat_arch}" ] && SKOPEO_PLAT_FLAGS+=(--override-arch "${_plat_arch}")
  [ -n "${_plat_var}" ]  && SKOPEO_PLAT_FLAGS+=(--override-variant "${_plat_var}")
fi

# Retries for skopeo
SKOPEO_RETRY_FLAGS=()
if [ "${SKOPEO_RETRIES:-0}" -gt 0 ]; then
  SKOPEO_RETRY_FLAGS=(--retry-times "${SKOPEO_RETRIES}")
fi

# Expand ${VARS} in charts.txt lines
expand_vars(){ eval "echo \"$1\""; }

# Logins
helm_login(){
  # $1 host  $2 password  $3 username
  # shellcheck disable=SC2086
  printf '%s' "$2" | helm registry login "$1" --username "$3" --password-stdin ${HELM_INSECURE_FLAGS} >/dev/null
}
login_dest(){ helm_login "$DST_REGISTRY" "$DST_PASSWORD" "$DST_USERNAME"; }
login_src_host(){
  local host="$1"
  [ -z "${SRC_USERNAME:-}" ] && [ -z "${SRC_PASSWORD:-}" ] && return 0
  # shellcheck disable=SC2086
  { printf '%s' "${SRC_PASSWORD}" | helm registry login "$host" --username "${SRC_USERNAME}" --password-stdin ${HELM_INSECURE_FLAGS} >/dev/null 2>&1 || true; }
}

# ---- Charts ----
CURRENT_CHART=""; CURRENT_VER=""

mirror_chart(){
  local oci="$1" host repo ver name pkg
  host="${oci#oci://}"; host="${host%%/*}"
  login_src_host "$host"

  ver="${oci##*:}"
  repo="${oci%:${ver}}"

  CURRENT_CHART="$repo"; CURRENT_VER="$ver"
  name="${repo##*/}"
  echo "[chart] $repo:$ver -> ${DST_REGISTRY}/${DST_PROJECT}/charts/${name}:$ver"

  # shellcheck disable=SC2086
  helm pull "$repo" --version "$ver" -d "${WORKDIR}/charts" ${HELM_INSECURE_FLAGS}
  pkg="${WORKDIR}/charts/${name}-${ver}.tgz"
  # shellcheck disable=SC2086
  helm push "$pkg" "oci://${DST_REGISTRY}/${DST_PROJECT}/charts" ${HELM_INSECURE_FLAGS}
}

download_chart(){
  local oci="$1" repo ver name pkg
  ver="${oci##*:}"
  repo="${oci%:${ver}}"
  CURRENT_CHART="$repo"; CURRENT_VER="$ver"
  name="${repo##*/}"
  pkg="${WORKDIR}/charts/${name}-${ver}.tgz"

  if [ -f "$pkg" ]; then
    if [ "${DOWNLOAD_SKIP_EXISTING:-1}" = "1" ]; then
      echo "[chart:dl] ${repo}:${ver} (skip: exists)"
      return 0
    elif [ "${DOWNLOAD_OVERWRITE:-0}" = "1" ]; then
      echo "[chart:dl] ${repo}:${ver} (overwrite)"
      rm -f "$pkg"
    else
      echo "[chart:dl] ${repo}:${ver} (exists; set DOWNLOAD_SKIP_EXISTING=1 or DOWNLOAD_OVERWRITE=1)"
      return 1
    fi
  else
    echo "[chart:dl] ${repo}:${ver}"
  fi
  # shellcheck disable=SC2086
  helm pull "$repo" --version "$ver" -d "${WORKDIR}/charts" ${HELM_INSECURE_FLAGS}
}

upload_chart(){
  local oci="$1" repo ver name pkg
  ver="${oci##*:}"
  repo="${oci%:${ver}}"
  CURRENT_CHART="$repo"; CURRENT_VER="$ver"
  name="${repo##*/}"
  pkg="${WORKDIR}/charts/${name}-${ver}.tgz"
  [ -f "$pkg" ] || { echo "  ! missing $pkg"; return 1; }
  echo "[chart:up] ${name}:${ver}"
  # shellcheck disable=SC2086
  helm push "$pkg" "oci://${DST_REGISTRY}/${DST_PROJECT}/charts" ${HELM_INSECURE_FLAGS}
}

# ---- Images (Skopeo) ----
# If an image line lacks ':tag', default to the CURRENT_VER (chart version)
ensure_tag(){
  case "$1" in
    *:*) printf '%s' "$1" ;;
    *)   printf '%s:%s' "$1" "$CURRENT_VER" ;;
  esac
}

mirror_image(){
  local ref0="$1"; local ref; ref="$(ensure_tag "$ref0")"
  local host="${ref%%/*}" path_tag="${ref#*/}"
  login_src_host "$host"
  local path="${path_tag%:*}" tag="${path_tag##*:}"
  local src_ref="docker://${host}/${path}:${tag}"
  local dst_ref="docker://${DST_REGISTRY}/${DST_PROJECT}/${path}:${tag}"
  echo "[image] ${host}/${path}:${tag} -> ${DST_REGISTRY}/${DST_PROJECT}/${path}:${tag}"
  skopeo copy ${SKOPEO_SRC_TLS} ${SKOPEO_DST_TLS} \
    "${SKOPEO_PLAT_FLAGS[@]}" \
    "${SKOPEO_RETRY_FLAGS[@]}" \
    ${SRC_USERNAME:+--src-creds "${SRC_USERNAME}:${SRC_PASSWORD}"} \
    --dest-creds "${DST_USERNAME}:${DST_PASSWORD}" \
    "$src_ref" "$dst_ref"
}

download_image(){
  local ref0="$1"; local ref; ref="$(ensure_tag "$ref0")"
  local host="${ref%%/*}" path_tag="${ref#*/}"
  local path="${path_tag%:*}" tag="${path_tag##*:}"
  local src_ref="docker://${host}/${path}:${tag}"
  local tar="${WORKDIR}/images/$(echo "${host}/${path}:${tag}" | tr '/:' '__').tar"

  if [ -f "$tar" ]; then
    if [ "${DOWNLOAD_SKIP_EXISTING:-1}" = "1" ]; then
      echo "[image:dl] ${host}/${path}:${tag} (skip: exists)"
      return 0
    elif [ "${DOWNLOAD_OVERWRITE:-0}" = "1" ]; then
      echo "[image:dl] ${host}/${path}:${tag} (overwrite)"
      rm -f "$tar"
    else
      echo "[image:dl] ${host}/${path}:${tag} (exists; set DOWNLOAD_SKIP_EXISTING=1 or DOWNLOAD_OVERWRITE=1)"
      return 1
    fi
  else
    echo "[image:dl] ${host}/${path}:${tag}"
  fi

  skopeo copy ${SKOPEO_SRC_TLS} \
    "${SKOPEO_PLAT_FLAGS[@]}" \
    "${SKOPEO_RETRY_FLAGS[@]}" \
    ${SRC_USERNAME:+--src-creds "${SRC_USERNAME}:${SRC_PASSWORD}"} \
    "$src_ref" "docker-archive:${tar}:${host}/${path}:${tag}"
}

upload_image(){
  local ref0="$1"; local ref; ref="$(ensure_tag "$ref0")"
  local host="${ref%%/*}" path_tag="${ref#*/}"
  local path="${path_tag%:*}" tag="${ref##*:}"
  local dst_ref="docker://${DST_REGISTRY}/${DST_PROJECT}/${path}:${tag}"
  local tar="${WORKDIR}/images/$(echo "${host}/${path}:${tag}" | tr '/:' '__').tar"
  [ -f "$tar" ] || { echo "  ! missing $tar"; return 1; }
  echo "[image:up] $tar -> ${DST_REGISTRY}/${DST_PROJECT}/${path}:${tag}"
  skopeo copy ${SKOPEO_DST_TLS} \
    --dest-creds "${DST_USERNAME}:${DST_PASSWORD}" \
    "docker-archive:${tar}" "$dst_ref"
}

# ---- run ----
login_dest

# Show first expanded chart line
first_chart_line="$(grep -E '^[[:space:]]*oci://[^#[:space:]]+' "$SOURCE_LIST" | head -n1 || true)"
if [ -n "$first_chart_line" ]; then
  first_chart_expanded="$(expand_vars "$first_chart_line")"
  echo "[debug] first chart line => ${first_chart_expanded}"
fi

while IFS= read -r raw; do
  line="$(expand_vars "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//;s/\r$//')"
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac

  if [[ "$line" == oci://* ]]; then
    case "$MODE" in
      mirror)   mirror_chart   "$line" ;;
      download) download_chart "$line" ;;
      upload)   upload_chart   "$line" ;;
    esac
  else
    case "$MODE" in
      mirror)   mirror_image   "$line" ;;
      download) download_image "$line" ;;
      upload)   upload_image   "$line" ;;
    esac
  fi
done < "$SOURCE_LIST"

echo "== Done ($MODE) =="
