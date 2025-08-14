#!/usr/bin/env bash
# ==============================================================================
# AKS cluster (create/delete) with API server accessible only from local/ip
#
# Usage:
#   ./aks-cluster.sh create
#   ./aks-cluster.sh delete
#
# Requires:
#   - env-vars.sh in the same directory (or set ENV_FILE to a custom path)
#   - Azure CLI logged in (./azure-login.sh)
#
# Key security behavior:
#   - Forces API server authorized IP ranges from env (defaults to LOCAL_IP/32)
#   - Hard-fails if any allowlist attempts 0.0.0.0/0 or '*'
#   - No SSH key by default; optional preview flag to disable SSH service
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/env-vars.sh}"
[[ -f "${ENV_FILE}" ]] && # shellcheck disable=SC1090
source "${ENV_FILE}"

ACTION="${1:-}"
if [[ "${ACTION}" != "create" && "${ACTION}" != "delete" ]]; then
  echo "Usage: $0 {create|delete}"
  exit 1
fi

throw_error() { echo "ERROR: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---- Required variables (pulled from env-vars.sh)
need_var() { local n="$1"; [[ -n "${!n:-}" ]] || throw_error "Required variable $n is not set. Check env-vars.sh"; }

need_var AKS_CLUSTER_NAME
need_var AKS_RESOURCE_GROUP
need_var AZ_LOCATION
need_var AKS_NODE_COUNT
need_var AKS_NODE_VM_SIZE
need_var AKS_NETWORK_PLUGIN
need_var DELETE_RESOURCE_GROUP_ON_CLEANUP
need_var GET_CREDENTIALS_AFTER_CREATE
need_var AKS_API_AUTHORIZED_IPS

# ---- Optional variables with sane defaults
: "${AKS_K8S_VERSION:=}"
: "${AZURE_TAGS:=}"
: "${AZ_SUBSCRIPTION_ID:=}"
: "${AKS_NO_SSH_KEY:=true}"             # default: no SSH key required
: "${AKS_DISABLE_SSH_SERVICE:=false}"   # default: don't toggle preview SSH disable
: "${AKS_SSH_PUBLIC_KEY:=}"             # optional path or inline key if you want SSH

# ---- CLI availability
echo "==> Checking required CLIs..."
have az || throw_error "Azure CLI (az) not found. Install: https://aka.ms/azure-cli"
have kubectl || echo "NOTE: kubectl not found. Will attempt 'az aks install-cli' if needed."

# ---- Login state
echo "==> Verifying Azure login state..."
 az account show --only-show-errors >/dev/null 2>&1 \
  || throw_error "Not logged in to Azure. Run ./azure-login.sh first."
[[ -n "${AZ_SUBSCRIPTION_ID}" ]] && az account set --subscription "${AZ_SUBSCRIPTION_ID}" --only-show-errors >/dev/null

# ---- Security guardrails on IP ranges
if [[ "${AKS_API_AUTHORIZED_IPS}" =~ (^|,)[[:space:]]*(\*|0\.0\.0\.0(/0)?)[[:space:]]*(,|$) ]]; then
  throw_error "AKS_API_AUTHORIZED_IPS contains 0.0.0.0/0 or '*'. Forbidden. Edit env-vars.sh."
fi

IFS=',' read -r -a _CIDRS <<< "${AKS_API_AUTHORIZED_IPS}"
for c in "${_CIDRS[@]}"; do
  [[ "${c}" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})$ ]] || throw_error "Bad CIDR in AKS_API_AUTHORIZED_IPS: '${c}'"
done

# ---- Helpers
rg_exists() {
  az group exists --name "${AKS_RESOURCE_GROUP}" --only-show-errors --output tsv
}

cluster_exists() {
  az aks show -g "${AKS_RESOURCE_GROUP}" -n "${AKS_CLUSTER_NAME}" --only-show-errors >/dev/null 2>&1
}

create_rg() {
  if [[ "$(rg_exists)" != "true" ]]; then
    echo "==> Creating resource group: ${AKS_RESOURCE_GROUP} (${AZ_LOCATION})"
    az group create \
      --name "${AKS_RESOURCE_GROUP}" \
      --location "${AZ_LOCATION}" \
      ${AZURE_TAGS:+ --tags ${AZURE_TAGS}} \
      --only-show-errors >/dev/null
  else
    echo "==> Resource group ${AKS_RESOURCE_GROUP} already exists."
  fi
}

ensure_kubectl() {
  if ! have kubectl; then
    echo "==> Installing kubectl via Azure CLI helper..."
    az aks install-cli --only-show-errors || true
    have kubectl || throw_error "kubectl installation failed; install manually and retry."
  fi
}

ensure_aks_disable_ssh_preview() {
  # Enable the preview bits only if user opted in
  if ! az extension show --name aks-preview --only-show-errors >/dev/null 2>&1; then
    az extension add --name aks-preview --only-show-errors
  else
    az extension update --name aks-preview --only-show-errors || true
  fi

  az feature register \
    --namespace "Microsoft.ContainerService" \
    --name "DisableSSHPreview" \
    --only-show-errors >/dev/null || true

  # Wait best-effort for feature registration
  for _ in {1..20}; do
    state="$(az feature show \
      --namespace Microsoft.ContainerService \
      --name DisableSSHPreview \
      --query properties.state -o tsv --only-show-errors 2>/dev/null || echo "")"
    [[ "$state" == "Registered" ]] && break
    sleep 6
  done

  az provider register --namespace Microsoft.ContainerService --only-show-errors >/dev/null || true
}

sync_api_server_ips() {
  echo "==> Syncing API server authorized IP ranges to: ${AKS_API_AUTHORIZED_IPS}"
  az aks update \
    --resource-group "${AKS_RESOURCE_GROUP}" \
    --name "${AKS_CLUSTER_NAME}" \
    --api-server-authorized-ip-ranges "${AKS_API_AUTHORIZED_IPS}" \
    --only-show-errors >/dev/null
}

create_cluster() {
  if cluster_exists; then
    echo "==> AKS cluster ${AKS_CLUSTER_NAME} already exists. Enforcing authorized IPs."
    sync_api_server_ips
  else
    local version_args=()
    [[ -n "${AKS_K8S_VERSION}" ]] && version_args=(--kubernetes-version "${AKS_K8S_VERSION}")

    local ssh_args=()
    if [[ "${AKS_DISABLE_SSH_SERVICE}" == "true" ]]; then
      echo "==> Enabling preview to disable SSH service on nodes..."
      ensure_aks_disable_ssh_preview
      ssh_args+=(--ssh-access disabled)   # preview
    fi
    if [[ "${AKS_NO_SSH_KEY}" == "true" ]]; then
      ssh_args+=(--no-ssh-key)            # GA: do not require an SSH key
    elif [[ -n "${AKS_SSH_PUBLIC_KEY:-}" ]]; then
      ssh_args+=(--ssh-key-value "${AKS_SSH_PUBLIC_KEY}")
    else
      ssh_args+=(--generate-ssh-keys)
    fi

    echo "==> Creating AKS cluster: ${AKS_CLUSTER_NAME}"
    az aks create \
      --resource-group "${AKS_RESOURCE_GROUP}" \
      --name "${AKS_CLUSTER_NAME}" \
      --location "${AZ_LOCATION}" \
      --enable-managed-identity \
      --enable-oidc-issuer \
      --enable-workload-identity \
      --node-count "${AKS_NODE_COUNT}" \
      --node-vm-size "${AKS_NODE_VM_SIZE}" \
      --network-plugin "${AKS_NETWORK_PLUGIN}" \
      --api-server-authorized-ip-ranges "${AKS_API_AUTHORIZED_IPS}" \
      ${AZURE_TAGS:+ --tags ${AZURE_TAGS}} \
      "${version_args[@]}" \
      "${ssh_args[@]}" \
      --only-show-errors
  fi

  if [[ "${GET_CREDENTIALS_AFTER_CREATE}" == "true" ]]; then
    ensure_kubectl
    echo "==> Fetching kubeconfig..."
    az aks get-credentials \
      -g "${AKS_RESOURCE_GROUP}" -n "${AKS_CLUSTER_NAME}" \
      --overwrite-existing --only-show-errors
    echo "==> Verifying cluster access..."
    kubectl get nodes -o wide
  fi

  echo "==> Done."
}

delete_cluster() {
  if ! cluster_exists; then
    echo "==> AKS cluster ${AKS_CLUSTER_NAME} does not exist. Nothing to delete."
  else
    echo "==> Deleting AKS cluster: ${AKS_CLUSTER_NAME}"
    az aks delete \
      -g "${AKS_RESOURCE_GROUP}" -n "${AKS_CLUSTER_NAME}" \
      --yes --only-show-errors
  fi

  if [[ "${DELETE_RESOURCE_GROUP_ON_CLEANUP}" == "true" && "$(rg_exists)" == "true" ]]; then
    echo "==> Deleting resource group: ${AKS_RESOURCE_GROUP}"
    az group delete -n "${AKS_RESOURCE_GROUP}" --yes --no-wait --only-show-errors
  fi

  echo "==> Done."
}

case "${ACTION}" in
  create) create_rg; create_cluster ;;
  delete) delete_cluster ;;
esac
