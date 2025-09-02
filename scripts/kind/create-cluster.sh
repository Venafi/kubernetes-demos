#!/usr/bin/env bash
set -Eeuo pipefail

# ========== Logging ==========
if [[ -n "${NO_COLOR:-}" ]]; then
  RESET=""; BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""
else
  RESET="\033[0m"; BOLD="\033[1m"
  RED="\033[1;31m"; GREEN="\033[1;32m"; YELLOW="\033[1;33m"
  BLUE="\033[1;34m"; MAGENTA="\033[1;35m"; CYAN="\033[1;36m"
fi

log_info()    { printf "\n${BLUE}[INFO] %s${RESET}\n" "$*"; }
log_warn()    { printf "\n${YELLOW}[WARN] %s${RESET}\n" "$*"; }
log_success() { printf "\n${GREEN}[OK]   %s${RESET}\n" "$*"; }
log_error()   { printf "\n${RED}[ERR]  %s${RESET}\n" "$*"; }

# =============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/env-vars.sh" ]] && source "${SCRIPT_DIR}/env-vars.sh" || true

command -v kind >/dev/null 2>&1 || { log_error "Missing dependency: kind"; exit 1; }
command -v date >/dev/null 2>&1 || { log_error "Missing dependency: date"; exit 1; }

NAME_PREFIX="${CLUSTER_NAME_PREFIX:-mis-demo-cluster}"
CLUSTER_NAME="${NAME_PREFIX}-$(date +%S%H%M%d%m)"
NODE_IMAGE="${KIND_NODE_IMAGE:-}"
PORTS_CSV="${EXTRA_PORT_MAPPINGS:-}"           # "80:80/TCP,443:443/TCP,8080:80/TCP"
MOUNTS_DIR_RAW="${EXTRA_MOUNTS_DIR:-extra-mounts}"

# Resolve mounts dir relative to the script
MOUNTS_DIR="$(cd "${SCRIPT_DIR}" && cd "${MOUNTS_DIR_RAW}" 2>/dev/null && pwd || true)"

# Optional node image
node_image_line=""
if [[ -n "${NODE_IMAGE}" ]]; then
  node_image_line="  image: ${NODE_IMAGE}"
fi

# extraPortMappings from EXTRA_PORT_MAPPINGS
port_yaml=""
if [[ -n "${PORTS_CSV// }" ]]; then
  IFS=',' read -r -a items <<< "${PORTS_CSV}"
  for item in "${items[@]}"; do
    [[ -z "${item// }" ]] && continue
    host="${item%%:*}"
    rest="${item#*:}"
    container="${rest%%/*}"
    proto="${rest#*/}"
    [[ "${proto}" == "${rest}" || -z "${proto}" ]] && proto="TCP"
    port_yaml+=$'\n'"  - containerPort: ${container}"
    port_yaml+=$'\n'"    hostPort: ${host}"
    port_yaml+=$'\n'"    protocol: ${proto}"
  done
  port_yaml=$'\n''  extraPortMappings:'"${port_yaml}"
fi

# extraMounts from *.pem in MOUNTS_DIR
mount_yaml=""
if [[ -n "${MOUNTS_DIR}" && -d "${MOUNTS_DIR}" ]]; then
  shopt -s nullglob
  pem_files=("${MOUNTS_DIR}"/*.pem)
  if ((${#pem_files[@]})); then
    mount_yaml=$'\n''  extraMounts:'
    for f in "${pem_files[@]}"; do
      base="$(basename "$f")"
      mount_yaml+=$'\n'"  - hostPath: ${f}"
      mount_yaml+=$'\n'"    containerPath: /etc/ssl/certs/${base}"
      mount_yaml+=$'\n'"    readOnly: true"
    done
  else
    log_warn "No *.pem files found in ${MOUNTS_DIR}; skipping extraMounts."
  fi
fi

render_config() {
  cat <<EOF
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
- role: control-plane
${node_image_line:+${node_image_line}}
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"${port_yaml}${mount_yaml}
EOF
}

if [[ "${SHOW_CONFIG:-0}" == "1" ]]; then
  echo "----- BEGIN KIND CONFIG -----" >&2
  render_config >&2
  echo "----- END KIND CONFIG -----" >&2
fi

log_info "Creating cluster ${CLUSTER_NAME}"
render_config | kind create cluster --name "${CLUSTER_NAME}" --config=-
log_success "Cluster '${CLUSTER_NAME}' is up."
