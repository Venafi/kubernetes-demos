#!/bin/bash

set -euo pipefail

echo "[clean] Full cleanup of CyberArk demo and Istio mesh setup"

# Safety checks
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR is required}"
: "${K8S_NAMESPACE:?K8S_NAMESPACE is required}"

# Ask for confirmation unless overridden
if [[ "${SKIP_CONFIRM:-}" != "true" ]]; then
  echo "⚠️ This will delete ALL resources created by scripts 01 through 08, including:"
  echo "- Namespaces: cyberark, sandbox, mesh-apps, istio-system"
  echo "- Secrets, certs, venafi issuers, sample apps, Istio, CyberArk install manifests"
  echo ""
  read -r -p "Are you sure? [y/N] " CONFIRM
  if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
    echo "[clean] Aborted by user."
    exit 0
  fi
fi

# Stop port-forwards
if [[ -x "$(dirname "$0")/show.sh" ]]; then
  echo "[clean] Stopping background port-forwards..."
  "$(dirname "$0")/show.sh" stop-port-forwards || true
fi

echo "should uninstall first -- work in progress" 

# Delete sample and demo namespaces
for ns in sandbox mesh-apps cyberark; do
  echo "[clean] Deleting namespace: ${ns}"
  kubectl delete namespace "$ns" --ignore-not-found
done

# Delete Istio system namespace 
echo "[clean] Attempting to delete istio-system ..."
kubectl delete namespace istio-system --ignore-not-found || true

# Delete Cyberark cluster-wide resources
echo "[clean] Deleting Cyberark Certificate Manager demo RBAC and policies..."
kubectl delete certificaterequestpolicy.cert-manager.io cert-policy-for-venafi-certs --ignore-not-found
kubectl delete certificaterequestpolicy.cert-manager.io cert-policy-for-venafi-firefly-certs --ignore-not-found
kubectl delete clusterrole venafi-issuer-cluster-role --ignore-not-found
kubectl delete clusterrolebinding venafi-issuer-cluster-role-binding --ignore-not-found
kubectl delete clusterrole read-creds-secret-role-for-venafi-connection --ignore-not-found
kubectl delete clusterrolebinding read-creds-secret-role-for-venafi-connection --ignore-not-found
kubectl delete venaficlusterissuer venafi-privateca-cluster-issuer --ignore-not-found
kubectl delete crd certificaterequestpolicies.policy.cert-manager.io --ignore-not-found || true

# Remove VenafiConnection + Secret
kubectl delete venaficonnection venafi-connection -n "$K8S_NAMESPACE" --ignore-not-found
kubectl delete secret venafi-cloud-credentials -n "$K8S_NAMESPACE" --ignore-not-found

# Clean up trust anchor and configmap
kubectl delete secret cyberark-trust-anchor -n "$K8S_NAMESPACE" --ignore-not-found
kubectl delete configmap istio-csr-ca -n "$K8S_NAMESPACE" --ignore-not-found

# Remove Istiod dynamic cert
kubectl delete certificate istiod-dynamic -n istio-system --ignore-not-found

# Clean up generated CyberArk install artifacts
if [[ "${PURGE_ARTIFACTS:-}" == "true" ]]; then
  echo "[clean] Removing generated artifacts at: ${ARTIFACTS_DIR}"
  rm -rf "${ARTIFACTS_DIR}"
fi

echo "[clean] ✅ Full demo environment teardown complete."
