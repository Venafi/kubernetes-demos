#!/usr/bin/env bash
# gke-cluster.sh — minimal create/delete/status (macOS/bash 3.2 friendly)
# Locks the API server to your IP via Master Authorized Networks.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/env-vars.sh}"
# shellcheck disable=SC1090
source "${ENV_FILE}"

"${SCRIPT_DIR}/gcp-login.sh"

loc_flags() {
  if [ -n "${ZONE:-}" ]; then
    printf -- "--zone %s" "${ZONE}"
  elif [ -n "${REGION:-}" ]; then
    printf -- "--region %s" "${REGION}"
  else
    printf ""
  fi
}

auth_nets() {
  local nets="${GKE_API_AUTHORIZED_IPS:-}"
  if [ -z "${nets}" ]; then
    echo "FATAL: GKE_API_AUTHORIZED_IPS is empty; check env-vars.sh" >&2
    return 1
  fi
  if [ -n "${GKE_API_EXTRA_CIDRS:-}" ]; then
    nets="${nets},${GKE_API_EXTRA_CIDRS}"
  fi
  printf "%s" "${nets}"
}

create() {
  LF="$(loc_flags)"
  AUTH_NETS="$(auth_nets)"
  echo "Locking API server to: ${AUTH_NETS}"

  echo "Checking if cluster '${CLUSTER_NAME}' exists..."
  if gcloud container clusters describe "${CLUSTER_NAME}" ${LF} >/dev/null 2>&1; then
    echo "Cluster exists — updating master authorized networks to desired IPs..."
    gcloud container clusters update "${CLUSTER_NAME}" ${LF}       \
            --enable-master-authorized-networks       \
            --master-authorized-networks "${AUTH_NETS}"
  else
    echo "Creating GKE cluster '${CLUSTER_NAME}'..."
    gcloud container clusters create "${CLUSTER_NAME}" ${LF} \
            --release-channel "${GKE_RELEASE_CHANNEL}" \
            --workload-pool "${PROJECT_ID}.svc.id.goog" \
            --num-nodes "${GKE_NODE_COUNT}" \
            --machine-type "${GKE_MACHINE_TYPE}" \
            --enable-shielded-nodes \
            --no-enable-basic-auth \
            --metadata disable-legacy-endpoints=true \
            --enable-master-authorized-networks \
            --master-authorized-networks "${AUTH_NETS}"
  fi

  echo "Fetching kubeconfig for '${CLUSTER_NAME}'..."
  gcloud container clusters get-credentials "${CLUSTER_NAME}" ${LF}
}

delete() {
  LF="$(loc_flags)"
  if gcloud container clusters describe "${CLUSTER_NAME}" ${LF} >/dev/null 2>&1; then
    echo "Deleting GKE cluster '${CLUSTER_NAME}'..."
    gcloud container clusters delete "${CLUSTER_NAME}" ${LF} --quiet
  else
    echo "Cluster '${CLUSTER_NAME}' not found; nothing to delete."
  fi
}

status() {
  gcloud container clusters list --format="table(name,location,status,releaseChannel.channel)"
}

authorize-ip() {
  LF="$(loc_flags)"
  AUTH_NETS="$(auth_nets)"
  echo "Updating master authorized networks to: ${AUTH_NETS}"
  gcloud container clusters update "${CLUSTER_NAME}" ${LF}     --enable-master-authorized-networks     --master-authorized-networks "${AUTH_NETS}"
}

show-allowed-ip() {
  LF="$(loc_flags)"
  gcloud container clusters describe "${CLUSTER_NAME}" ${LF}     --format="value(masterAuthorizedNetworksConfig.cidrBlocks)"
}

case "${1:-}" in
  create) create ;;
  delete) delete ;;
  status) status ;;
  authorize-ip) authorize_ip ;;
  show-allowed-ip) show-allowed-ip ;;
  *)
    cat <<EOF
Usage: $0 {create|delete|status|authorize-ip|show-allowed-ip}

Environment (set in env-vars.sh):
  LOCAL_IP_CMD            Command to detect your public IP (with fallbacks).
  LOCAL_IP                Cached public IP value.
  GKE_API_AUTHORIZED_IPS  Comma-separated CIDRs, default "\${LOCAL_IP}/32".
  GKE_API_EXTRA_CIDRS     Optional extra CIDRs to allow (comma-separated).

Examples:
  ./gke-cluster.sh create
  GKE_API_EXTRA_CIDRS="203.0.113.0/24" ./gke-cluster.sh authorize-ip
  ./gke-cluster.sh show-allowed-ip
EOF
    exit 2
    ;;
esac
