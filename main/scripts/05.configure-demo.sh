#!/bin/bash

set -euo pipefail

echo "[configure-demo] Creating CertificateRequestPolicies and configuring Venafi components..."

# Validate required environment variables
: "${K8S_NAMESPACE:?K8S_NAMESPACE is required}"
: "${CYBR_CLOUD_API_KEY:?CYBR_CLOUD_API_KEY is required}"
: "${CYBR_ZONE_PRIVATE_CA:?CYBR_ZONE_PRIVATE_CA is required}"

echo "[INFO] Target namespace: ${K8S_NAMESPACE}"
echo "[INFO] Venafi zone: ${CYBR_ZONE_PRIVATE_CA}"

# Create CertificateRequestPolicies and RBAC
cat <<EOF | kubectl apply -f -
---
apiVersion: policy.cert-manager.io/v1alpha1
kind: CertificateRequestPolicy
metadata:
  name: cert-policy-for-venafi-certs
spec:
  allowed:
    commonName:
      value: "*"
    dnsNames:
      values: ["*"]
    subject:
      organizations:
        values: ["*"]
      countries:
        values: ["*"]
      organizationalUnits:
        values: ["*"]
      localities:
        values: ["*"]
      provinces:
        values: ["*"]
      streetAddresses:
        values: ["*"]
      postalCodes:
        values: ["*"]
    usages:
      - "signing"
      - "digital signature"
      - "server auth"
  selector:
    issuerRef:
      name: "venafi*issuer"
      kind: "Venafi*Issuer"
      group: "jetstack.io"
---
apiVersion: policy.cert-manager.io/v1alpha1
kind: CertificateRequestPolicy
metadata:
  name: cert-policy-for-venafi-firefly-certs
spec:
  allowed:
    commonName:
      value: "*"
    dnsNames:
      values: ["*"]
    uris:
      values:
        - "spiffe://cluster.local/ns/*/sa/*"
    isCA: false
    subject:
      organizations:
        values: ["*"]
      countries:
        values: ["*"]
      organizationalUnits:
        values: ["*"]
      localities:
        values: ["*"]
      provinces:
        values: ["*"]
      streetAddresses:
        values: ["*"]
      postalCodes:
        values: ["*"]
    usages:
      - "signing"
      - "digital signature"
      - "client auth"
      - "server auth"
  selector:
    issuerRef:
      name: "*"
      kind: "*"
      group: "firefly.venafi.com"
    namespace:
      matchNames:
        - "sandbox"
        - "*istio-system"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: venafi-issuer-cluster-role
rules:
  - apiGroups: ["policy.cert-manager.io"]
    resources: ["certificaterequestpolicies"]
    verbs: ["use"]
    resourceNames: ["cert-policy-for-venafi-certs", "cert-policy-for-venafi-firefly-certs"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: venafi-issuer-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: venafi-issuer-cluster-role
subjects:
  - kind: ServiceAccount
    name: cert-manager
    namespace: ${K8S_NAMESPACE}
  - kind: ServiceAccount
    name: cert-manager-istio-csr
    namespace: ${K8S_NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: read-creds-secret-role-for-venafi-connection
rules:
  - apiGroups: [""]
    resources:
      - secrets
    verbs:
      - get
    resourceNames:
      - venafi-tpp-credentials
      - venafi-cloud-credentials
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-creds-secret-role-for-venafi-connection
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: read-creds-secret-role-for-venafi-connection
subjects:
  - kind: ServiceAccount
    name: venafi-connection
    namespace: ${K8S_NAMESPACE}
EOF

# Create Kubernetes secret for Venafi Cloud credentials
echo "[configure-demo] Creating secret 'venafi-cloud-credentials' in '${K8S_NAMESPACE}' namespace..."
kubectl create secret generic venafi-cloud-credentials \
  --namespace "${K8S_NAMESPACE}" \
  --from-literal=venafi-cloud-key="${CYBR_CLOUD_API_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create VenafiConnection CR
echo "[configure-demo] Creating VenafiConnection..."
cat <<EOF | kubectl apply -f -
apiVersion: jetstack.io/v1alpha1
kind: VenafiConnection
metadata:
  name: venafi-connection
  namespace: ${K8S_NAMESPACE}
spec:
  vaas:
    apiKey:
      - secret:
          name: venafi-cloud-credentials
          fields: ["venafi-cloud-key"]
EOF

# Create VenafiClusterIssuer CR
echo "[configure-demo] Creating VenafiClusterIssuer..."
cat <<EOF | kubectl apply -f -
apiVersion: jetstack.io/v1alpha1
kind: VenafiClusterIssuer
metadata:
  name: venafi-privateca-cluster-issuer
spec:
  venafiConnectionName: venafi-connection
  zone: ${CYBR_ZONE_PRIVATE_CA}
EOF

# Wait for the issuer to become ready
echo "[configure-demo] Waiting for VenafiClusterIssuer to become Ready..."
kubectl wait venaficlusterissuer venafi-privateca-cluster-issuer \
  --for=condition=Ready=True --timeout=60s || {
    echo "[ERROR] VenafiClusterIssuer did not become Ready in time."
    exit 1
}

# Summary validation
echo "[configure-demo] Validating created Kubernetes resources..."
kubectl get certificaterequestpolicy
kubectl get clusterrole venafi-issuer-cluster-role
kubectl get clusterrolebinding venafi-issuer-cluster-role-binding
kubectl get clusterrole read-creds-secret-role-for-venafi-connection
kubectl get clusterrolebinding read-creds-secret-role-for-venafi-connection
kubectl get secret venafi-cloud-credentials -n "${K8S_NAMESPACE}"
kubectl get venaficonnection venafi-connection -n "${K8S_NAMESPACE}"
kubectl get venaficlusterissuer

echo "[configure-demo] CyberArk Certificate Manager demo configuration complete ✅"