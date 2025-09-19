#!/usr/bin/env bash
set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/env-vars.sh"

# --- Prechecks ---
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found"; exit 1; }

APP_NS="${APP_NS:-sandbox}"
APP_NAME="${APP_NAME:-echo}"

# Optional overrides for hostnames
: "${VS1_HOST:=${DNS_NAME}}"
: "${VS2_HOST:=issuer-${DNS_SUFFIX}.${DNS_BASE_DOMAIN}}"
: "${VS3_HOST:=cluster-${DNS_SUFFIX}.${DNS_BASE_DOMAIN}}"

# Label selector to find the secret created in validate-ccm
: "${CERT_SECRET_LABEL_SELECTOR:=app=sample1}"

# Issuer names (namespaced and cluster)
: "${ISSUER_NAME:=venafi-saas-issuer}"
: "${ISSUER_KIND:=VenafiIssuer}"
: "${ISSUER_GROUP:=jetstack.io}"
: "${CLUSTER_ISSUER_NAME:=venafi-saas-cluster-issuer}"

echo ">> Validating service ${APP_NAME} in namespace ${APP_NS}"
if ! kubectl -n "${APP_NS}" get svc "${APP_NAME}" >/dev/null 2>&1; then
  echo "ERROR: Service ${APP_NAME} not found in namespace ${APP_NS}. Run 02.validate-nginx.sh first."
  exit 1
fi

echo ">> Ensuring namespace ${APP_NS} exists"
kubectl get ns "${APP_NS}" >/dev/null 2>&1 || kubectl create namespace "${APP_NS}"

# ================================
# Virtual Server 1 - TLS secret
# ================================
echo ">> Looking up TLS secret with label selector '${CERT_SECRET_LABEL_SELECTOR}' in ${APP_NS}"
VS1_SECRET_NAME="$(kubectl -n "${APP_NS}" get secret -l "${CERT_SECRET_LABEL_SELECTOR}" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | head -n1 || true)"

if [[ -z "${VS1_SECRET_NAME}" ]]; then
  echo "ERROR: No secret found with label ${CERT_SECRET_LABEL_SELECTOR} in namespace ${APP_NS}."
  echo "       Make sure 04.validate-ccm.sh created a cert whose secretTemplate includes that label."
  exit 1
fi

echo ">> Creating VirtualServer vs1-tlssecret (host: ${VS1_HOST}, secret: ${VS1_SECRET_NAME})"
cat <<EOF | kubectl apply -f -
apiVersion: k8s.nginx.org/v1
kind: VirtualServer
metadata:
  name: vs1-tlssecret
  namespace: ${APP_NS}
spec:
  host: ${VS1_HOST}
  tls:
    secret: ${VS1_SECRET_NAME}
  upstreams:
  - name: ${APP_NAME}-svc
    service: ${APP_NAME}
    port: 80
  routes:
  - path: /
    action:
      pass: ${APP_NAME}-svc
EOF

# ================================
# Virtual Server 2 - cert-manager centerprise issuer VenafiIssuer(namespaced)
# ================================
echo ">> Creating VirtualServer vs2-issuer (host: ${VS2_HOST}, issuer: ${ISSUER_NAME} kind=${ISSUER_KIND} group=${ISSUER_GROUP})"
cat <<EOF | kubectl apply -f -
apiVersion: k8s.nginx.org/v1
kind: VirtualServer
metadata:
  name: vs2-issuer
  namespace: ${APP_NS}
spec:
  host: ${VS2_HOST}
  tls:
   secret: ${VS2_HOST}
   cert-manager:
     issuer: ${ISSUER_NAME}
     issuer-kind: ${ISSUER_KIND}
     issuer-group: ${ISSUER_GROUP}
     common-name: ${VS2_HOST}
     duration: 720h
     renew-before: 480h
     usages: digital signature,server auth,client auth  
  upstreams:
  - name: ${APP_NAME}-svc
    service: ${APP_NAME}
    port: 80
  routes:
  - path: /
    action:
      pass: ${APP_NAME}-svc
EOF

# ================================
# Virtual Server 3 - cert-manager enterprise issuer VenafiClusterIssuer 
# ================================
echo ">> Creating VirtualServer vs3-clusterissuer (host: ${VS3_HOST}, cluster-issuer: ${CLUSTER_ISSUER_NAME})"
cat <<EOF | kubectl apply -f -
apiVersion: k8s.nginx.org/v1
kind: VirtualServer
metadata:
  name: vs3-clusterissuer
  namespace: ${APP_NS}
spec:
  host: ${VS3_HOST}
  tls:
    secret: ${VS3_HOST}
    cert-manager:
      cluster-issuer: ${CLUSTER_ISSUER_NAME}
      issuer-kind: VenafiClusterIssuer
      issuer-group: ${ISSUER_GROUP}
  upstreams:
  - name: ${APP_NAME}-svc
    service: ${APP_NAME}
    port: 80
  routes:
  - path: /
    action:
      pass: ${APP_NAME}-svc
EOF

echo ">> Listing VirtualServers in ${APP_NS}:"
kubectl -n "${APP_NS}" get virtualserver -o wide || true

LB="$(kubectl -n "${NAMESPACE}" get svc -l app.kubernetes.io/name=nginx-ingress \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}{"\n"}{.items[0].status.loadBalancer.ingress[0].hostname}{"\n"}' \
  | head -n1)"

echo ">> Done. Test with (LB=$LB):"
echo "  VS1_HOST=${VS1_HOST}"
echo "  VS2_HOST=${VS2_HOST}"
echo "  VS3_HOST=${VS3_HOST}"
echo
echo "  # HTTPS tests"
echo "  curl -vk --resolve \"${VS1_HOST}:443:${LB}\" https://${VS1_HOST}/"
echo "  curl -vk --resolve \"${VS2_HOST}:443:${LB}\" https://${VS2_HOST}/"
echo "  curl -vk --resolve \"${VS3_HOST}:443:${LB}\" https://${VS3_HOST}/"
