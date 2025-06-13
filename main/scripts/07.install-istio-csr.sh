#!/bin/bash

set -euo pipefail

echo "[install-istio-csr] Preparing environment for Istio service mesh..."

# Validate required env vars
: "${K8S_NAMESPACE:?K8S_NAMESPACE is required}"
: "${CERT_MANAGER_ISTIO_CSR:?CERT_MANAGER_ISTIO_CSR is required}"
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR is required}"

INSTALL_DIR="${ARTIFACTS_DIR}/cyberark-install"
VALUES_OUT="${INSTALL_DIR}/istio-csr-values.yaml"

# Generate Helm values file dynamically
echo "[install-istio-csr] Templating istio-csr Helm values..."
sed -e "s|cert-manager-istio-csr.cyberark.svc|cert-manager-istio-csr.${K8S_NAMESPACE}.svc|g" \
  templates/helm/istio-csr-values.yaml > "${VALUES_OUT}"

# Create issuer used by istio-csr for signing SVIDs
echo "[install-istio-csr] Creating SPIFFE-compatible issuer for mesh identities..."
kubectl apply -n istio-system -f templates/servicemesh/firefly-mesh-wi-issuer.yaml

# If using CCM built in automatically provided
# If others, accounting for value set in env-vars.sh 
# Ideally the secret cyberark-trust-anchor is created using ESO with Cyberark Secrets Manager so it's managed in one place when 
# trust needs to be created in multiple clusters.
CYBR_TRUST_ANCHOR_ROOT_CA_PEM="${CYBR_TRUST_ANCHOR_ROOT_CA_PEM:-${ARTIFACTS_DIR}/venafi-cloud-built-in-root.pem}"
# Create trust anchor secret from CYBR_TRUST_ANCHOR_ROOT_CA_PEM
kubectl create secret generic cyberark-trust-anchor \
  --namespace="${K8S_NAMESPACE}" \
  --from-file=root-cert.pem="${CYBR_TRUST_ANCHOR_ROOT_CA_PEM}" \
  --dry-run=client --save-config=true -o yaml | kubectl apply -f -

# Create configmap that tells istio-csr how to request SVIDs
echo "[install-istio-csr] Creating istio-csr ConfigMap for Venafi Issuer wiring..."
kubectl create configmap istio-csr-ca --namespace="${K8S_NAMESPACE}" \
  --from-literal=issuer-name=firefly-mesh-wi-issuer \
  --from-literal=issuer-kind=Issuer \
  --from-literal=issuer-group=firefly.venafi.com \
  --dry-run=client --save-config=true -o yaml | kubectl apply -f -

# Apply trust anchor to istio-system (used by SPIRE components and Istio CA fallback)
kubectl apply -n istio-system -f templates/servicemesh/firefly-trust-anchor.yaml

# Generate manifests for istio-csr component
echo "[install-istio-csr] Generating manifests for istio-csr..."
venctl components kubernetes manifest generate \
  --namespace "${K8S_NAMESPACE}" \
  --istio-csr \
  --istio-csr-version "${CERT_MANAGER_ISTIO_CSR}" \
  --istio-csr-values-files istio-csr-values.yaml \
  --ignore-dependencies \
  --image-pull-secret-names venafi-image-pull-secret \
  > "${INSTALL_DIR}/venafi-manifests-istio.yaml"

# Sync manifests to cluster
: "${ISTIO_TRUST_DOMAIN:=cluster.local}"
echo "[install-istio-csr] Applying manifests via venctl sync..."
ISTIO_TRUST_DOMAIN="${ISTIO_TRUST_DOMAIN}" \
venctl components kubernetes manifest tool sync \
  --file "${INSTALL_DIR}/venafi-manifests-istio.yaml"

# Wait for istiod signing cert to be ready
echo "[install-istio-csr] Waiting for istiod-dynamic certificate to be ready..."
kubectl wait certificate istiod-dynamic -n istio-system \
  --for=condition=Ready=True --timeout=90s

# Summarize the certificate created
echo ""
echo "✅ [install-istio-csr] ISTIOD certificate ready:"
kubectl get certificate istiod-dynamic -n istio-system -o custom-columns=\
NAME:.metadata.name,\
ANNOTATIONS:.metadata.annotations.firefly\\.venafi\\.com/policy-name,\
COMMON_NAME:.spec.commonName,\
DNS_NAMES:'{.spec.dnsNames[*]}',\
DURATION:.spec.duration,\
ISSUER:.spec.issuerRef.name,\
SECRET_NAME:.spec.secretName,\
URIS:'{.spec.uris[*]}'

echo ""
echo "[install-istio-csr] Environment prepared for Istio Service Mesh installation ✅"
