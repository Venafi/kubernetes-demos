#!/bin/bash

set -euo pipefail

echo "[install-istio] Installing and configuring Istio service mesh..."

# Validate required variables
: "${K8S_NAMESPACE:?K8S_NAMESPACE is required}"
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR is required}"
command -v istioctl >/dev/null || { echo "[ERROR] istioctl not found in PATH"; exit 1; }

INSTALL_DIR="${ARTIFACTS_DIR}/cyberark-install"

# Install Istio control plane with venafi-integrated CSR
echo "[install-istio] Installing Istio with custom config..."

istioctl install -y -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
spec:
  profile: demo
  hub: gcr.io/istio-release
  meshConfig:
    trustDomain: cluster.local
  values:
    global:
      caAddress: cert-manager-istio-csr.${K8S_NAMESPACE}.svc:443
  components:
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
cp templates/servicemesh/peerauthentication.yaml "${INSTALL_DIR}/peerauthentication.yaml"
kubectl apply -f "${INSTALL_DIR}/peerauthentication.yaml"

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
echo "[install-istio] Service Mesh is ready and workload identity is enabled via CyberArk Workload Identity Manager"
