#!/usr/bin/env bash
set -euo pipefail

echo "[ccm-operator] 🧭 Installing CyberArk Certificate Manager via Operator..."

# Ensure required variables are present
: "${INSTALL_DIR:?INSTALL_DIR not set — must be run via 04.install.sh}"
: "${CYBR_AGENT_SA_CLIENT_ID:?Missing agent SA client ID}"
: "${CYBR_FIREFLY_SA_CLIENT_ID:?Missing firefly SA client ID}"
: "${RESOURCE_SUFFIX:?Missing RESOURCE_SUFFIX}"
: "${K8S_NAMESPACE:?Missing K8S_NAMESPACE}"

CLUSTER_NAME="mis-demo-cluster-${RESOURCE_SUFFIX}"

AGENT_VALUES=$(<"${INSTALL_DIR}/venafi-agent.yaml")
FIREFLY_VALUES=$(<"${INSTALL_DIR}/firefly-values.yaml")
VEI_VALUES=$(<"${INSTALL_DIR}/vei-values.yaml")

# Apply OperatorGroup
echo "[ccm-operator] Creating OperatorGroup..."
cat <<EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cyberark-operator-group
  namespace: ${K8S_NAMESPACE}
spec:
  upgradeStrategy: Default
EOF

# Apply Subscription
echo "[ccm-operator] Creating Subscription for vcp-operator..."
cat <<EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: vcp-operator
  namespace: ${K8S_NAMESPACE}
spec:
  channel: stable
  name: vcp-operator
  source: certified-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

# Wait for CSV to install
echo "[ccm-operator] Waiting for CSV to reach Succeeded state..."
CSV_NAME=""
for _ in {1..30}; do
  CSV_NAME=$(kubectl get subscription vcp-operator -n "$K8S_NAMESPACE" -o jsonpath='{.status.installedCSV}' || true)
  if [[ -n "$CSV_NAME" ]]; then break; fi
  sleep 5
done

if [[ -z "$CSV_NAME" ]]; then
  echo "[ccm-operator] ❌ CSV not found after waiting."
  exit 1
fi

for _ in {1..30}; do
  PHASE=$(kubectl get csv "$CSV_NAME" -n "$K8S_NAMESPACE" -o jsonpath='{.status.phase}' || echo "Missing")
  if [[ "$PHASE" == "Succeeded" ]]; then
    echo "[ccm-operator] ✅ CSV $CSV_NAME is ready (phase: Succeeded)"
    break
  fi
  echo "[ccm-operator] ⏳ CSV $CSV_NAME phase: $PHASE (waiting...)"
  sleep 5
done

PHASE=$(kubectl get csv "$CSV_NAME" -n "$K8S_NAMESPACE" -o jsonpath='{.status.phase}' || echo "Missing")
if [[ "$PHASE" != "Succeeded" ]]; then
  echo "[ccm-operator] ❌ CSV did not reach 'Succeeded' phase. Current phase: $PHASE"
  exit 1
fi

# Construct and apply VenafiInstall CR
VENAFI_INSTALL_FILE="${INSTALL_DIR}/venafi-install.yaml"
echo "[ccm-operator] Creating VenafiInstall CR at ${VENAFI_INSTALL_FILE}"

cat <<EOF > "$VENAFI_INSTALL_FILE"
apiVersion: installer.venafi.com/v1alpha1
kind: VenafiInstall
metadata:
  name: cyberark-cm-for-kubernetes
spec:
  globals:
    namespace: ${K8S_NAMESPACE}
    enableDefaultApprover: false
    useFIPSImages: false
    region: US
    vcpRegion: US
    imagePullSecretNames:
      - venafi-image-pull-secret

  approverPolicyEnterprise:
    install: true
    version: ${APPROVER_POLICY_ENTERPRISE}

  certManager:
    install: true
    version: ${CERT_MANAGER}

  certManagerCSIDriver:
    install: true
    version: ${CERT_MANAGER_CSI_DRIVER}

  certManagerCSIDriverSPIFFE:
    install: true
    version: ${CERT_MANAGER_CSI_DRIVER_SPIFFE}
    trustDomain: cluster.local

  trustManager:
    install: true
    version: ${TRUST_MANAGER}

  firefly:
    install: true
    version: ${FIREFLY}
    clientID: ${CYBR_FIREFLY_SA_CLIENT_ID}
    acceptTOS: true
    values:
$(echo "$FIREFLY_VALUES" | sed 's/^/      /')

  venafiConnection:
    install: true
    version: ${VENAFI_CONNECTION}

  venafiEnhancedIssuer:
    install: true
    version: ${VENAFI_ENHANCED_ISSUER}
    values:
$(echo "$VEI_VALUES" | sed 's/^/      /')

  venafiKubernetesAgent:
    install: true
    version: ${VENAFI_KUBERNETES_AGENT}
    clientID: ${CYBR_AGENT_SA_CLIENT_ID}
    values:
$(echo "$AGENT_VALUES" | sed 's/^/      /')

  openshiftRoutes:
    install: true
    version: ${OPENSHIFT_ROUTES}
EOF

echo "[ccm-operator] Applying VenafiInstall Custom Resource..."
kubectl apply -f "$VENAFI_INSTALL_FILE"

echo "[ccm-operator] ✅ Operator-based install complete."
