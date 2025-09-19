#!/usr/bin/env bash
set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/env-vars.sh"

# --- Prechecks ---
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found"; exit 1; }
command -v venctl  >/dev/null 2>&1 || { echo "venctl not found (install CyberArk Certificate Manager CLI)"; exit 1; }
command -v jq      >/dev/null 2>&1 || { echo "jq not found"; exit 1; }

mkdir -p "${TMP_ARTIFACTS_DIR}"

# ------------------------------
# Create Registry service account in Cyberark Certificate Manager and extract Kubernetes secret
# ------------------------------
echo ">> Creating CCM Registry service account: ${CCM_REGISTRY_SVC_ACCT_NAME}"
venctl iam service-account registry create \
  --name "${CCM_REGISTRY_SVC_ACCT_NAME}" \
  --output-file "${TMP_ARTIFACTS_DIR}/${CCM_REGISTRY_SVC_ACCT_NAME}.json" \
  --output "secret" \
  --owning-team "${CCM_TEAM_NAME}" \
  --validity 10 \
  --scopes cert-manager-components,enterprise-approver-policy,enterprise-venafi-issuer,openshift-routes \
  --api-key "${CCM_APIKEY}" \
  --vcp-region "${CCM_CLOUD_REGION}"

jq -r '.image_pull_secret' "${TMP_ARTIFACTS_DIR}/${CCM_REGISTRY_SVC_ACCT_NAME}.json" > "${TMP_ARTIFACTS_DIR}/${CCM_REGISTRY_SVC_ACCT_NAME}.yaml"

echo ">> Ensuring Cyberark Certifcate Manager namespace ${CCM_NAMESPACE}"
kubectl get ns "${CCM_NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${CCM_NAMESPACE}"

echo ">> Creating image pull secret from CCM in cluster"
kubectl --namespace "${CCM_NAMESPACE}" apply -f "${TMP_ARTIFACTS_DIR}/${CCM_REGISTRY_SVC_ACCT_NAME}.yaml"

# ------------------------------
# Generate and sync Kubernetes manifests for Cyberark Certificate Manager components
# ------------------------------
echo ">> Generating Venafi manifests -> ${CCM_MANIFESTS_FILE}"
venctl components kubernetes manifest generate \
  --namespace "${CCM_NAMESPACE}" \
  --cert-manager \
  --venafi-connection \
  --venafi-enhanced-issuer \
  --default-approver \
  --image-pull-secret-names venafi-image-pull-secret  > "${CCM_MANIFESTS_FILE}"

echo ">> Applying CyberArk Certificate Manager manifests"
venctl components kubernetes manifest tool sync --file "${CCM_MANIFESTS_FILE}"

