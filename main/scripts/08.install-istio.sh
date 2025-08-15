#!/bin/bash

set -euo pipefail

echo "[install-istio] Installing and configuring Istio service mesh..."

# Validate required variables
: "${K8S_NAMESPACE:?K8S_NAMESPACE is required}"
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR is required}"
command -v istioctl >/dev/null || { echo "[ERROR] istioctl not found in PATH"; exit 1; }

INSTALL_DIR="${ARTIFACTS_DIR}/cyberark-install"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# -------- Random default for security group used for ingress load balancer --------
CIDR_FALLBACK="1.2.3.4/32"

if [[ -z "${CIDR:-}" || "$CIDR" == "REPLACE_WITH_LOCAL_CIDR" ]]; then
  if command -v curl >/dev/null; then
    PUBLIC_IP=$(curl -s --connect-timeout 2 https://checkip.amazonaws.com || true)
    if [[ -n "$PUBLIC_IP" && "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      CIDR="${PUBLIC_IP}/32"
      echo "[install-istio] ✅ Using public IP: $CIDR for ingress access"
    else
      echo "[install-istio] ⚠️ Could not determine public IP. Falling back to $CIDR_FALLBACK"
      CIDR="$CIDR_FALLBACK"
    fi
  else
    echo "[install-istio] ⚠️ curl not available. Falling back to $CIDR_FALLBACK"
    CIDR="$CIDR_FALLBACK"
  fi
else
  echo "[install-istio] ✅ Using provided CIDR: $CIDR"
fi

if "$SCRIPTS_DIR/helper/redhat/is-openshift-cluster.sh"; then
  export ISTIO_INSTALL_PROFILE="openshift"
else
  export ISTIO_INSTALL_PROFILE="demo"
fi
echo "[install-istio] Selected Istio profile: ${ISTIO_INSTALL_PROFILE}"

# Install Istio control plane with venafi-integrated CSR
echo "[install-istio] Installing Istio with custom config..."

istioctl install -y -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
spec:
  profile: ${ISTIO_INSTALL_PROFILE}
  hub: gcr.io/istio-release
  meshConfig:
    trustDomain: cluster.local
  values:
    global:
      caAddress: cert-manager-istio-csr.${K8S_NAMESPACE}.svc:443
  components:
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        service:
          type: LoadBalancer
          loadBalancerSourceRanges:
          - "${CIDR}"
    pilot:
      k8s:
        env:
        - name: ENABLE_CA_SERVER
          value: "false"
EOF

# Label app namespace for automatic sidecar injection
kubectl label namespace mesh-apps istio-injection=enabled --overwrite

# Apply mTLS PeerAuthentication policy
echo "[install-istio] Enforcing mTLS across mesh..."
cat <<EOF | kubectl apply -f -
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "global"
  namespace: "istio-system"
spec:
  mtls:
    mode: STRICT
EOF


# Install sample microservices demo
echo "[install-istio] Deploying CyberArk swag shop demo..."
kubectl -n mesh-apps apply -f https://raw.githubusercontent.com/sitaramkm/microservices-demo/refs/heads/main/release/kubernetes-manifests.yaml

# Install Istio observability addons
echo "[install-istio] Deploying observability tools..."
for addon in kiali prometheus grafana; do
  kubectl apply -f "https://raw.githubusercontent.com/istio/istio/refs/heads/release-1.24/samples/addons/${addon}.yaml"
done

# Wait for important deployments
echo "[install-istio] Waiting for Istio and add-ons to be ready..."
kubectl rollout status deployment/istiod -n istio-system --timeout=90s || true
kubectl rollout status deployment/kiali -n istio-system --timeout=90s || true
kubectl rollout status deployment/grafana -n istio-system --timeout=90s || true

echo ""
echo "✅ Istio Mesh Deployment Summary:"
echo " 1. Installed Istio using istioctl with CSR backed by CyberArk"
echo " 2. Applied mTLS policy (STRICT) across the mesh"
echo " 3. Deployed CyberArk swag shop in 'mesh-apps' (with sidecar injection)"
echo " 4. Deployed observability stack: Kiali, Prometheus, Grafana"
echo ""
echo "🚀 What's next:"
echo "→ Run './cloud-demo.sh show svid frontend' to inspect the SPIFFE SVID issued to the frontend app"
echo "→ Run './cloud-demo.sh show app-url' to launch the swag shop demo in your browser"
echo "→ Run './cloud-demo.sh show stop-port-forwards' to clean up background port forwards"
echo ""
echo "🔍 Access CyberArk Certificate Manager UI (https://<your-tenant>.venafi.cloud)"
echo "   Navigate to: *Inventory → Firefly Issuer Certificates* to view workload identities"
echo ""
echo "🧹 When you're done, clean up resources with:"
echo "   ./cloud-demo.sh clean"
echo ""
echo "[install-istio] Service Mesh is ready and workload identity is enabled via CyberArk Workload Identity Manager"
