#!/bin/bash

set -euo pipefail

echo "[install] Generating Helm manifests and installing CyberArk components..."

# Validate required environment variables
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR is required}"
: "${K8S_NAMESPACE:?K8S_NAMESPACE is required}"
: "${RESOURCE_SUFFIX:?RESOURCE_SUFFIX is required}"
: "${CERT_MANAGER:?CERT_MANAGER is required}"
: "${CERT_MANAGER_CSI_DRIVER:?}"
: "${CERT_MANAGER_CSI_DRIVER_SPIFFE:?}"
: "${FIREFLY:?}"
: "${TRUST_MANAGER:?}"
: "${VENAFI_CONNECTION:?}"
: "${VENAFI_ENHANCED_ISSUER:?}"
: "${VENAFI_KUBERNETES_AGENT:?}"
: "${APPROVER_POLICY_ENTERPRISE:?}"

INSTALL_DIR="${ARTIFACTS_DIR}/cyberark-install"
mkdir -p "$INSTALL_DIR"

# Override suffix if resource file exists
SUFFIX_FILE="${ARTIFACTS_DIR}/resource-suffix.txt"
if [ -f "$SUFFIX_FILE" ]; then
  RESOURCE_SUFFIX="$(<"$SUFFIX_FILE")"
  echo "Overriding RESOURCE_SUFFIX with value from file: $RESOURCE_SUFFIX"
fi

# Validate required files exist
[[ -s templates/helm/cloud-vei-values.yaml ]] || { echo "[ERROR] Missing template: cloud-vei-values.yaml"; exit 1; }
[[ -s templates/helm/venafi-agent.yaml ]] || { echo "[ERROR] Missing template: venafi-agent.yaml"; exit 1; }

echo "Copying templates to ${INSTALL_DIR}..."
cp templates/helm/cloud-vei-values.yaml "${INSTALL_DIR}/vei-values.yaml"
sed -e "s/REPLACE_WITH_CLUSTER_NAME/mis-demo-cluster-${RESOURCE_SUFFIX}/g" \
  templates/helm/venafi-agent.yaml > "${INSTALL_DIR}/venafi-agent.yaml"

# Generate manifest
echo "[install] Generating manifest with venctl..."
venctl components kubernetes manifest generate \
  --namespace "${K8S_NAMESPACE}" \
  --approver-policy-enterprise \
  --approver-policy-enterprise-version "${APPROVER_POLICY_ENTERPRISE}" \
  --cert-manager \
  --cert-manager-version "${CERT_MANAGER}" \
  --csi-driver \
  --csi-driver-version "${CERT_MANAGER_CSI_DRIVER}" \
  --csi-driver-spiffe \
  --csi-driver-spiffe-version "${CERT_MANAGER_CSI_DRIVER_SPIFFE}" \
  --accept-firefly-tos \
  --firefly \
  --firefly-version "${FIREFLY}" \
  --trust-manager \
  --trust-manager-version "${TRUST_MANAGER}" \
  --venafi-connection \
  --venafi-connection-version "${VENAFI_CONNECTION}" \
  --venafi-enhanced-issuer \
  --venafi-enhanced-issuer-version "${VENAFI_ENHANCED_ISSUER}" \
  --venafi-enhanced-issuer-values-files vei-values.yaml \
  --venafi-kubernetes-agent \
  --venafi-kubernetes-agent-version "${VENAFI_KUBERNETES_AGENT}" \
  --venafi-kubernetes-agent-values-files venafi-agent.yaml \
  --image-pull-secret-names venafi-image-pull-secret \
  > "${INSTALL_DIR}/venafi-manifests.yaml"

echo "[install] Manifest generated at ${INSTALL_DIR}/venafi-manifests.yaml"

# Read service account client IDs
CYBR_AGENT_SA_CLIENT_ID="$(<"${INSTALL_DIR}/cybr_mis_agent_client_id.txt")"
CYBR_FIREFLY_SA_CLIENT_ID="$(<"${INSTALL_DIR}/cybr_mis_firefly_client_id.txt")"

# Prompt for confirmation
while [ -z "${CONFIRM:-}" ]; do
  read -r -p "Have you attached the Firefly service account to the config in the UI? [y/N] " CONFIRM
done

if [ "$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')" != "y" ]; then
  echo "######################################################################"
  echo "The Firefly config must be associated with the client ID:"
  echo "  ${CYBR_FIREFLY_SA_CLIENT_ID}"
  echo "Do this in the CyberArk UI before continuing."
  echo "######################################################################"
  exit 1
fi

# Optionally allow override of trust domain
: "${CSI_DRIVER_SPIFFE_TRUST_DOMAIN:=cluster.local}"

echo "[install] Syncing manifests to cluster..."
VENAFI_KUBERNETES_AGENT_CLIENT_ID="${CYBR_AGENT_SA_CLIENT_ID}" \
FIREFLY_VENAFI_CLIENT_ID="${CYBR_FIREFLY_SA_CLIENT_ID}" \
CSI_DRIVER_SPIFFE_TRUST_DOMAIN="${CSI_DRIVER_SPIFFE_TRUST_DOMAIN}" \
venctl components kubernetes manifest tool sync --file "${INSTALL_DIR}/venafi-manifests.yaml"

echo "[install] Installation complete ✅"
