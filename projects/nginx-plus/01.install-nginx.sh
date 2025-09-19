#!/usr/bin/env bash
set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/env-vars.sh"

# --- Prechecks ---
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm not found"; exit 1; }
[ -f "$JWT_FILE" ] || { echo "Missing JWT file: $JWT_FILE"; exit 1; }

echo ">> Creating namespace ${NAMESPACE} if it does not exist"
kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

echo ">> Creating image pull secret (${PULL_SECRET_NAME}) for F5 private registry"
kubectl -n "${NAMESPACE}" delete secret "${PULL_SECRET_NAME}" --ignore-not-found
kubectl -n "${NAMESPACE}" create secret docker-registry "${PULL_SECRET_NAME}" \
  --docker-server=private-registry.nginx.com \
  --docker-username="$(cat "${JWT_FILE}")" \
  --docker-password="none"

echo ">> Creating NGINX Plus license secret (${LICENSE_SECRET_NAME})"
kubectl -n "${NAMESPACE}" delete secret "${LICENSE_SECRET_NAME}" --ignore-not-found
kubectl -n "${NAMESPACE}" create secret generic "${LICENSE_SECRET_NAME}" \
  --from-file=license.jwt="${JWT_FILE}" \
  --type=nginx.com/license

echo ">> Installing NGINX Plus Ingress Controller via Helm (chart ${NGINX_PLUS_VERSION})"
helm upgrade --install "${RELEASE_NAME}" "${NGINX_PLUS_CHART}" \
  --version "${NGINX_PLUS_VERSION}" \
  --namespace "${NAMESPACE}" --create-namespace \
  --set controller.nginxplus=true \
  --set controller.image.repository="${IMG_REPO}" \
  --set controller.serviceAccount.imagePullSecretName="${PULL_SECRET_NAME}" \
  --set controller.mgmt.licenseTokenSecretName="${LICENSE_SECRET_NAME}" \
  --set controller.service.type=LoadBalancer \
  --set controller.enableCertManager=true    # <<< enable cert-manager integration

echo ">> Waiting for controller to be Available..."
kubectl -n "${NAMESPACE}" wait --for=condition=Available deploy -l app.kubernetes.io/name=nginx-ingress --timeout=180s || true

echo ">> install-nginx.sh complete."
