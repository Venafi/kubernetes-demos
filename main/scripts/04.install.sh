#!/usr/bin/env bash
set -euo pipefail

echo "[install] Installing CyberArk Certificate Manager..."

# Accept optional install mode: venctl (default) or operator
INSTALL_MODE="${1:-venctl}"

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
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Override suffix if file exists
SUFFIX_FILE="${ARTIFACTS_DIR}/resource-suffix.txt"
if [ -f "$SUFFIX_FILE" ]; then
  RESOURCE_SUFFIX="$(<"$SUFFIX_FILE")"
  echo "Overriding RESOURCE_SUFFIX with value from file: $RESOURCE_SUFFIX"
fi

# Validate template inputs
[[ -s templates/helm/cloud-vei-values.yaml ]] || { echo "[ERROR] Missing cloud-vei-values.yaml"; exit 1; }
[[ -s templates/helm/venafi-agent.yaml ]] || { echo "[ERROR] Missing venafi-agent.yaml"; exit 1; }
[[ -s templates/helm/firefly-values.yaml ]] || { echo "[ERROR] Missing firefly-values.yaml"; exit 1; }

echo "[install] Copying and templating Helm values..."
cp templates/helm/cloud-vei-values.yaml "${INSTALL_DIR}/vei-values.yaml"

sed -e "s/REPLACE_WITH_CLUSTER_NAME/mis-demo-cluster-${RESOURCE_SUFFIX}/g" \
  templates/helm/venafi-agent.yaml > "${INSTALL_DIR}/venafi-agent-tmp.yaml"
envsubst < "${INSTALL_DIR}/venafi-agent-tmp.yaml" > "${INSTALL_DIR}/venafi-agent.yaml"

envsubst < templates/helm/firefly-values.yaml > "${INSTALL_DIR}/firefly-values.yaml"

# Read client IDs
CYBR_AGENT_SA_CLIENT_ID="$(<"${INSTALL_DIR}/cybr_mis_agent_client_id.txt")"
CYBR_FIREFLY_SA_CLIENT_ID="$(<"${INSTALL_DIR}/cybr_mis_firefly_client_id.txt")"

# Confirm Firefly service account has been linked in the UI
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

# If using Operator install, delegate and exit
if [[ "$INSTALL_MODE" == "operator" ]]; then
  if ! "$SCRIPTS_DIR/helper/redhat/is-openshift-cluster.sh"; then
    echo "[install] ❌ Operator install is only supported on OpenShift clusters."
    exit 1
  fi
  echo "[install] 🚀 Switching to operator-based install flow..."
  # Export required variables for ccm-operator.sh
  export INSTALL_DIR
  export CYBR_AGENT_SA_CLIENT_ID
  export CYBR_FIREFLY_SA_CLIENT_ID
  export RESOURCE_SUFFIX
  exec "$(dirname "$0")/ccm-operator.sh"
fi

# -------------------------
# venctl-based install flow
# -------------------------
echo "[install] 🛠️ Generating manifest with venctl..."

venctl components kubernetes manifest generate \
  --region "${CYBR_CLOUD_REGION}" \
  --vcp-region "${CYBR_CLOUD_REGION}" \
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
  --firefly-values-files firefly-values.yaml \
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

# Optionally allow override of trust domain
: "${CSI_DRIVER_SPIFFE_TRUST_DOMAIN:=cluster.local}"

echo "[install] 📡 Syncing manifests to cluster..."
VENAFI_KUBERNETES_AGENT_CLIENT_ID="${CYBR_AGENT_SA_CLIENT_ID}" \
FIREFLY_VENAFI_CLIENT_ID="${CYBR_FIREFLY_SA_CLIENT_ID}" \
CSI_DRIVER_SPIFFE_TRUST_DOMAIN="${CSI_DRIVER_SPIFFE_TRUST_DOMAIN}" \
venctl components kubernetes manifest tool sync --file "${INSTALL_DIR}/venafi-manifests.yaml"

echo "[install] ✅ venctl-based install complete"
