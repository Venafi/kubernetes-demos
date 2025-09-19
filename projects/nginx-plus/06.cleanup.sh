#!/usr/bin/env bash
set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/env-vars.sh"

# ------------------------------
# Delete RBAC
# ------------------------------
echo ">> Deleting RBAC for reading CCM credentials"
kubectl -n "${CCM_NAMESPACE}" delete role read-ccm-credentials --ignore-not-found || true
kubectl -n "${CCM_NAMESPACE}" delete rolebinding read-ccm-credentials --ignore-not-found || true

# ------------------------------
# Delete Issuer in app namespace
# ------------------------------
echo ">> Deleting VenafiIssuer in ${APP_NS}"
kubectl -n "${APP_NS}" delete venafiissuer venafi-saas-issuer --ignore-not-found
echo ">> Deleting VenafiClusterIssuer"
kubectl delete venaficlusterissuer venafi-saas-cluster-issuer --ignore-not-found

# ------------------------------
# Delete VenafiConnection and related secrets in CCM namespace
# ------------------------------
echo ">> Deleting VenafiConnection and secrets in ${CCM_NAMESPACE}"
kubectl -n "${CCM_NAMESPACE}" delete venaficonnection venafi-saas-connection-cross-ns --ignore-not-found
kubectl -n "${CCM_NAMESPACE}" delete venaficonnection venafi-saas-connection-cluster-wide --ignore-not-found
kubectl -n "${CCM_NAMESPACE}" delete secret venafi-cloud-credentials venafi-image-pull-secret --ignore-not-found


# ------------------------------
# Delete namespaces (optional)
# ------------------------------
echo ">> Deleting APP_NS ${APP_NS} (optional)"
kubectl delete namespace "${APP_NS}" --ignore-not-found || true

# ------------------------------
# Tear down generated Venafi manifests (if present)
# ------------------------------
if [[ -f "${CCM_MANIFESTS_FILE}" ]]; then
  echo ">> Destroying resources described in ${CCM_MANIFESTS_FILE} via venctl"
  venctl components kubernetes manifest tool destroy --file "${CCM_MANIFESTS_FILE}" || true
else
  echo ">> Skipping venctl destroy: ${CCM_MANIFESTS_FILE} not found"
fi

helm -n "${NAMESPACE}" uninstall "${RELEASE_NAME}" || true

echo ">> Deleting CCM namespace ${CCM_NAMESPACE}"
kubectl delete namespace "${CCM_NAMESPACE}" "${NAMESPACE}" --ignore-not-found || true

echo ">> Deleting all leftover CRDS"
# requires: jq
delete_crds_by_group() {
  local group="$1"
  # Get CRD names for the API group
  crds="$(kubectl get crds -o json \
    | jq -r --arg g "$group" '.items[] | select(.spec.group==$g) | .metadata.name')"

  if [ -n "$crds" ]; then
    echo "$crds" | while IFS= read -r name; do
      [ -n "$name" ] && kubectl delete crd "$name"
    done
  else
    echo "No CRDs for group: $group"
  fi
}

delete_crds_by_group jetstack.io
delete_crds_by_group cert-manager.io
delete_crds_by_group acme.cert-manager.io
delete_crds_by_group k8s.nginx.org
delete_crds_by_group externaldns.nginx.org
delete_crds_by_group appprotectdos.f5.com
delete_crds_by_group appprotect.f5.com

echo ">> cleanup.sh complete."
