#!/bin/bash

set -euo pipefail

echo "[clean] Full cleanup of CyberArk demo and Istio mesh setup"

# Safety checks
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR is required}"
: "${K8S_NAMESPACE:?K8S_NAMESPACE is required}"

INSTALL_DIR="${ARTIFACTS_DIR}/cyberark-install"
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
# Remove Istio observability addons
echo "[clean] removing observability tools..."
for addon in kiali prometheus grafana; do
  kubectl delete -f "https://raw.githubusercontent.com/istio/istio/refs/heads/release-1.24/samples/addons/${addon}.yaml" || true
done

# remove sample microservices demo
echo "[clean] removing CyberArk swag shop demo...:"
kubectl -n mesh-apps delete -f https://raw.githubusercontent.com/sitaramkm/microservices-demo/refs/heads/main/release/kubernetes-manifests.yaml || true


# uninstall istio
istioctl uninstall -y --purge || true

# uninstall istio-csr 
# Sync manifests to cluster
: "${ISTIO_TRUST_DOMAIN:=cluster.local}"
echo "[clean] Removing install-istio-csr..."
ISTIO_TRUST_DOMAIN="${ISTIO_TRUST_DOMAIN}" \
venctl components kubernetes manifest tool destroy \
  --file "${INSTALL_DIR}/venafi-manifests-istio.yaml"

# Remove Istiod dynamic cert
kubectl -n istio-system delete certificate istiod-dynamic --ignore-not-found
kubectl -n istio-system delete Issuer firefly-mesh-wi-issuer --ignore-not-found 
kubectl delete Bundle istio-ca-root-cert --ignore-not-found 
kubectl -n "$K8S_NAMESPACE" delete secret cyberark-trust-anchor --ignore-not-found 
kubectl -n "$K8S_NAMESPACE" delete configmap istio-csr-ca  --ignore-not-found

for ns in mesh-apps istio-system; do
  echo "[clean] Deleting namespace: ${ns}"
  kubectl delete namespace "$ns" --ignore-not-found
done

kubectl delete clusterrole istiod-istio-system || true 
kubectl delete clusterrole istio-reader-istio-system || true
kubectl delete clusterrolebinding istiod-istio-system || true
kubectl delete clusterrolebinding istio-reader-istio-system || true
kubectl get crds | grep 'istio.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true

for workload in expiry-eddie unmanaged-kid cipher-snake; do
  echo "[clean] Deleting deployment: ${workload}"
  kubectl delete deployment "${workload}-nginx" --ignore-not-found
  kubectl delete service "${workload}-nginx" --ignore-not-found
done

for cert in expiry-eddie ghost-rider; do
  echo "[clean] Deleting certificate: ${cert}"
  kubectl delete Certificate "${cert}.svc.cluster.local" --ignore-not-found
done

for secret in unmanaged-kid.svc.cluster.local cipher-snake.svc.cluster.local phantom-ca; do
  echo "[clean] Deleting secret: ${secret}"
  kubectl delete Secret "${secret}" --ignore-not-found
done


# Delete Cyberark cluster-wide resources
echo "[clean] Deleting Cyberark Certificate Manager demo RBAC and policies..."
kubectl delete venaficlusterissuer venafi-privateca-cluster-issuer --ignore-not-found
kubectl -n ${K8S_NAMESPACE} delete VenafiConnection venafi-connection --ignore-not-found
kubectl -n ${K8S_NAMESPACE} delete Secret venafi-cloud-credentials --ignore-not-found
kubectl delete clusterrolebinding read-creds-secret-role-for-venafi-connection --ignore-not-found
kubectl delete clusterrole read-creds-secret-role-for-venafi-connection --ignore-not-found
kubectl delete clusterrolebinding venafi-issuer-cluster-role-binding --ignore-not-found
kubectl delete clusterrole venafi-issuer-cluster-role --ignore-not-found
kubectl delete certificaterequestpolicies.policy.cert-manager.io cert-policy-for-venafi-firefly-certs --ignore-not-found
kubectl delete certificaterequestpolicies.policy.cert-manager.io cert-policy-for-venafi-certs --ignore-not-found

echo "[clean] Uninstall all Cyberark Certificate Manager components..."
# Read service account client IDs
CYBR_AGENT_SA_CLIENT_ID="$(<"${INSTALL_DIR}/cybr_mis_agent_client_id.txt")"
CYBR_FIREFLY_SA_CLIENT_ID="$(<"${INSTALL_DIR}/cybr_mis_firefly_client_id.txt")"
# Optionally allow override of trust domain
: "${CSI_DRIVER_SPIFFE_TRUST_DOMAIN:=cluster.local}"

VENAFI_KUBERNETES_AGENT_CLIENT_ID="${CYBR_AGENT_SA_CLIENT_ID}" \
FIREFLY_VENAFI_CLIENT_ID="${CYBR_FIREFLY_SA_CLIENT_ID}" \
CSI_DRIVER_SPIFFE_TRUST_DOMAIN="${CSI_DRIVER_SPIFFE_TRUST_DOMAIN}" \
venctl components kubernetes manifest tool destroy --file "${INSTALL_DIR}/venafi-manifests.yaml"

for ns in sandbox cyberark; do
  echo "[clean] Deleting namespace: ${ns}"
  kubectl delete namespace "$ns" --ignore-not-found
done

# Handle suffix override from file
SUFFIX_FILE="${ARTIFACTS_DIR}/resource-suffix.txt"
if [ -f "$SUFFIX_FILE" ]; then
  RESOURCE_SUFFIX="$(<"$SUFFIX_FILE")"
  echo "Overriding RESOURCE_SUFFIX with value from file: $RESOURCE_SUFFIX"
else
  : "${RESOURCE_SUFFIX:?RESOURCE_SUFFIX is required or missing from suffix file}"
fi

echo "[clean] Fetching service accounts matching mis-demo-*-${RESOURCE_SUFFIX}..."

# Fetch all service accounts and filter matching names
venctl iam service-accounts list \
  --api-key "${CYBR_CLOUD_API_KEY}" \
  --api-url "${CLOUD_URL}" \
  --vcp-region "${CYBR_CLOUD_REGION}" \
  --log-format json | jq -r --arg suffix "${RESOURCE_SUFFIX}" '
    .[] | select(.name | test("^mis-demo-.*-" + $suffix + "$")) | .name' | while read -r sa_name; do
      echo "[clean] 🔥 Deleting service account: $sa_name"
      venctl iam service-accounts delete \
        --api-key "${CYBR_CLOUD_API_KEY}" \
        --api-url "${CLOUD_URL}" \
        --vcp-region "${CYBR_CLOUD_REGION}" \
        --name "$sa_name" \
        --no-prompts || echo "[clean] ❌ Failed to delete: $sa_name"
done

# Clean up generated CyberArk install artifacts
if [[ "${PURGE_ARTIFACTS:-}" == "true" ]]; then
  echo "[clean] Removing generated artifacts at: ${ARTIFACTS_DIR}"
  rm -rf "${ARTIFACTS_DIR}"
fi

echo "[clean] ✅ Full demo environment teardown complete."
