#!/usr/bin/env bash
set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/env-vars.sh"

# --- Prechecks ---
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found"; exit 1; }
# ------------------------------
# Sample echo app + Service
# ------------------------------
echo ">> Ensuring app namespace ${APP_NS}"
kubectl get ns "${APP_NS}" >/dev/null 2>&1 || kubectl create namespace "${APP_NS}"

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${APP_NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      containers:
      - name: ${APP_NAME}
        image: ${APP_IMAGE}
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}
  namespace: ${APP_NS}
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: ${APP_NAME}
EOF

echo ">> Waiting for echo deployment to be Ready..."
kubectl -n "${APP_NS}" rollout status deploy/${APP_NAME} --timeout=120s || true

# ------------------------------
# VirtualServer
# ------------------------------
echo ">> Applying VirtualServer ${VS_NAME} (host ${DNS_NAME})"
cat <<EOF | kubectl apply -f -
apiVersion: k8s.nginx.org/v1
kind: VirtualServer
metadata:
  name: ${VS_NAME}
  namespace: ${APP_NS}
spec:
  host: ${DNS_NAME}
  upstreams:
  - name: ${APP_NAME}-svc
    service: ${APP_NAME}
    port: 80
  routes:
  - path: /
    action:
      pass: ${APP_NAME}-svc
EOF

echo ">> VirtualServer status:"
kubectl -n "${APP_NS}" get virtualserver "${VS_NAME}" -o wide || true

# ------------------------------
# Print LoadBalancer info
# ------------------------------
echo ">> Discovering controller LoadBalancer address..."
LB_IP="$(kubectl -n "${NAMESPACE}" get svc -l app.kubernetes.io/name=nginx-ingress \
  -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.status.loadBalancer.ingress[0].ip}{end}')"
LB_HOSTNAME="$(kubectl -n "${NAMESPACE}" get svc -l app.kubernetes.io/name=nginx-ingress \
  -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.status.loadBalancer.ingress[0].hostname}{end}')"

LB_TARGET="${LB_IP:-$LB_HOSTNAME}"

echo
if [ -n "${LB_TARGET}" ]; then
  echo ">> Test HTTP routing with:"
  echo "curl -i -H \"Host: ${DNS_NAME}\" http://${LB_TARGET}/"
else
  echo "!! No LoadBalancer address yet. Check later with:"
  echo "kubectl get svc -n ${NAMESPACE}"
  echo "Then test with: curl -i -H \"Host: ${DNS_NAME}\" http://<LB_IP_OR_HOST>/"
fi

echo ">> Simple NGINX Plus validation complete."
