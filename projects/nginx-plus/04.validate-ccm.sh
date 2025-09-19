#!/usr/bin/env bash
set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/env-vars.sh"

# --- Prechecks ---
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found"; exit 1; }
: "${CCM_NAMESPACE:?CCM_NAMESPACE is required (set in env-vars.sh)}"
: "${APP_NS:?APP_NS is required (set in env-vars.sh)}"
: "${CERT_ZONE:?CERT_ZONE is required (set in env-vars.sh)}"
: "${CCM_APIKEY:?CCM_APIKEY is required (set in env-vars.sh)}"
: "${DNS_BASE_DOMAIN:?DNS_BASE_DOMAIN is required (set in env-vars.sh, e.g. apps.example.com)}"

# ------------------------------
# CyberArk API key secret
# ------------------------------
echo ">> Creating venafi-cloud-credentials Secret in ${CCM_NAMESPACE}"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: venafi-cloud-credentials
  namespace: ${CCM_NAMESPACE}
stringData:
  venafi-cloud-key: ${CCM_APIKEY}
EOF

# ------------------------------
# VenafiConnections: cross-ns and cluster-wide
# ------------------------------
echo ">> Creating cross-namespace VenafiConnection in ${CCM_NAMESPACE}"
kubectl apply -f - <<EOF
apiVersion: jetstack.io/v1alpha1
kind: VenafiConnection
metadata:
  name: venafi-saas-connection-cross-ns
  namespace: ${CCM_NAMESPACE}
spec:
  allowReferencesFrom:
    matchLabels:
      kubernetes.io/metadata.name: ${APP_NS}
  vaas:
    url: https://api.venafi.cloud
    apiKey:
    - secret:
        name: venafi-cloud-credentials
        fields: ["venafi-cloud-key"]
EOF

echo ">> Creating cluster-wide VenafiConnection in ${CCM_NAMESPACE}"
kubectl apply -f - <<EOF
apiVersion: jetstack.io/v1alpha1
kind: VenafiConnection
metadata:
  name: venafi-saas-connection-cluster-wide
  namespace: ${CCM_NAMESPACE}
spec:
  vaas:
    url: https://api.venafi.cloud
    apiKey:
    - secret:
        name: venafi-cloud-credentials
        fields: ["venafi-cloud-key"]
EOF

# ------------------------------
# RBAC for reading the API key Secret
# ------------------------------
echo ">> Applying RBAC so Venafi components can read venafi-cloud-credentials"
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: read-ccm-credentials
  namespace: ${CCM_NAMESPACE}
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["venafi-cloud-credentials"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-ccm-credentials
  namespace: ${CCM_NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: read-ccm-credentials
subjects:
- kind: ServiceAccount
  name: venafi-connection
  namespace: ${CCM_NAMESPACE}
EOF

# ------------------------------
# Ensure app namespace and create issuers
# ------------------------------
echo ">> Ensuring app namespace ${APP_NS}"
kubectl get ns "${APP_NS}" >/dev/null 2>&1 || kubectl create namespace "${APP_NS}"

echo ">> Creating VenafiIssuer (namespaced) in ${APP_NS}"
kubectl apply -f - <<EOF
apiVersion: jetstack.io/v1alpha1
kind: VenafiIssuer
metadata:
  name: venafi-saas-issuer
  namespace: ${APP_NS}
spec:
  venafiConnectionName: venafi-saas-connection-cross-ns
  venafiConnectionNamespace: ${CCM_NAMESPACE}
  zone: ${CERT_ZONE}
EOF

echo ">> Creating VenafiClusterIssuer (cluster-wide)"
kubectl apply -f - <<EOF
apiVersion: jetstack.io/v1alpha1
kind: VenafiClusterIssuer
metadata:
  name: venafi-saas-cluster-issuer
spec:
  venafiConnectionName: venafi-saas-connection-cluster-wide
  zone: ${CERT_ZONE}
EOF

# ------------------------------
# Helper: create a Certificate
# Default CN/SAN = ${DNS_NAME}, or generated from ${DNS_BASE_DOMAIN}
# ------------------------------
create_certificate() {
  local issuer_name="$1"   # e.g., venafi-saas-issuer or venafi-saas-cluster-issuer
  local issuer_kind="$2"   # VenafiIssuer or VenafiClusterIssuer
  local issuer_group="$3"  # jetstack.io

  # Compose DNS_NAME if not provided
  if [[ -z "${DNS_NAME:-}" ]]; then
    DNS_SUFFIX="$(date +%S%H%M%d%m)"
    DNS_NAME="nginx-${DNS_SUFFIX}.${DNS_BASE_DOMAIN}"
  fi

  echo ">> Requesting Certificate ${DNS_NAME} in ${APP_NS} using ${issuer_kind}/${issuer_name} (${issuer_group})"
  kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${DNS_NAME}
  namespace: ${APP_NS}
spec:
  secretTemplate:
    labels:
      app: sample1
      env: dev
  secretName: ${DNS_NAME}
  commonName: ${DNS_NAME}
  duration: 24h
  renewBefore: 8h
  issuerRef:
    name: ${issuer_name}
    kind: ${issuer_kind}
    group: ${issuer_group}
  privateKey:
    rotationPolicy: Always
    size: 2048
  dnsNames:
  - ${DNS_NAME}
EOF

  echo ">> Waiting up to 30s for Certificate ${DNS_NAME} to be Ready..."
  for i in {1..30}; do
    READY="$(kubectl -n "${APP_NS}" get certificate "${DNS_NAME}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
    if [[ "${READY}" == "True" ]]; then
      echo "#################################################"
      echo "Certificate ${DNS_NAME} is Ready"
      echo "Secret: ${DNS_NAME} (labels: app=sample1, env=dev)"
      return 0
    fi
    sleep 1
  done

  echo "!! Certificate ${DNS_NAME} not Ready after 30s"
  echo "   Troubleshoot with:"
  echo "     kubectl -n ${APP_NS} describe certificate ${DNS_NAME}"
  echo "     kubectl -n ${APP_NS} describe certificaterequest -l cert-manager.io/certificate-name=${DNS_NAME}"
  return 1
}

# ------------------------------
# Behavior:
#   ./04.validate-ccm.sh                 -> uses namespaced issuer
#   ./04.validate-ccm.sh use-cluster-issuer -> uses cluster issuer
# ------------------------------
if [[ "${1:-}" == "use-cluster-issuer" ]]; then
  create_certificate "venafi-saas-cluster-issuer" "VenafiClusterIssuer" "jetstack.io"
else
  create_certificate "venafi-saas-issuer" "VenafiIssuer" "jetstack.io"
fi
