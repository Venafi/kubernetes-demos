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

# Remove Istio observability addons
echo "[clean] removing observability tools..."
for addon in kiali prometheus grafana; do
  kubectl delete -f "https://raw.githubusercontent.com/istio/istio/refs/heads/release-1.24/samples/addons/${addon}.yaml" || true
done

# remove sample microservices demo
echo "[clean] removing CyberArk swag shop demo...:"
#kubectl -n mesh-apps delete -f https://raw.githubusercontent.com/sitaramkm/microservices-demo/refs/heads/main/release/kubernetes-manifests.yaml || true
kubectl -n mesh-apps delete -f https://raw.githubusercontent.com/sitaramkm/microservices-demo/c11da444de264e91a80380ebad330eaa32ed0a83/release/kubernetes-manifests.yaml || true

# uninstall istio
istioctl uninstall -y --purge || true

# uninstall istio-csr 
# Sync manifests to cluster
: "${ISTIO_TRUST_DOMAIN:=cluster.local}"
echo "[clean] Removing install-istio-csr..."
ISTIO_TRUST_DOMAIN="${ISTIO_TRUST_DOMAIN}" \
venctl components kubernetes manifest tool destroy \
  --file "${INSTALL_DIR}/venafi-manifests-istio.yaml" || true

# Remove Istiod dynamic cert
kubectl -n istio-system delete certificate istiod-dynamic --ignore-not-found || true
kubectl -n istio-system delete Issuer firefly-mesh-wi-issuer --ignore-not-found || true
kubectl delete Bundle istio-ca-root-cert --ignore-not-found || true
kubectl -n "$K8S_NAMESPACE" delete secret cyberark-trust-anchor --ignore-not-found || true
kubectl -n "$K8S_NAMESPACE" delete configmap istio-csr-ca  --ignore-not-found || true

for ns in mesh-apps istio-system; do
  echo "[clean] Deleting namespace: ${ns}"
  kubectl delete namespace "$ns" --ignore-not-found || true
done

kubectl delete clusterrole istiod-istio-system || true 
kubectl delete clusterrole istio-reader-istio-system || true
kubectl delete clusterrolebinding istiod-istio-system || true
kubectl delete clusterrolebinding istio-reader-istio-system || true
kubectl get crds | grep 'istio.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true

for workload in expiry-eddie unmanaged-kid cipher-snake; do
  echo "[clean] Deleting deployment: ${workload}"
  kubectl -n sandbox delete deployment "${workload}-nginx" --ignore-not-found || true
  kubectl -n sandbox delete service "${workload}-nginx" --ignore-not-found || true
done

for cert in expiry-eddie ghost-rider; do
  echo "[clean] Deleting certificate: ${cert}"
  kubectl -n sandbox delete Certificate "${cert}.svc.cluster.local" --ignore-not-found || true
done

for secret in unmanaged-kid.svc.cluster.local cipher-snake.svc.cluster.local phantom-ca; do
  echo "[clean] Deleting secret: ${secret}"
  kubectl -n sandbox delete Secret "${secret}" --ignore-not-found || true
done


# Delete Cyberark cluster-wide resources
echo "[clean] Deleting Cyberark Certificate Manager demo RBAC and policies..."
kubectl delete venaficlusterissuer venafi-privateca-cluster-issuer --ignore-not-found || true
kubectl -n ${K8S_NAMESPACE} delete VenafiConnection venafi-connection --ignore-not-found || true
kubectl -n ${K8S_NAMESPACE} delete Secret venafi-cloud-credentials --ignore-not-found || true
kubectl delete clusterrolebinding read-creds-secret-role-for-venafi-connection --ignore-not-found || true
kubectl delete clusterrole read-creds-secret-role-for-venafi-connection --ignore-not-found || true
kubectl delete clusterrolebinding venafi-issuer-cluster-role-binding --ignore-not-found || true
kubectl delete clusterrole venafi-issuer-cluster-role --ignore-not-found || true
kubectl delete certificaterequestpolicies.policy.cert-manager.io cert-policy-for-venafi-firefly-certs --ignore-not-found || true
kubectl delete certificaterequestpolicies.policy.cert-manager.io cert-policy-for-venafi-certs --ignore-not-found || true

echo "[clean] Uninstall all Cyberark Certificate Manager components..."

echo "[clean] 🧽 Removing Operator-based installation artifacts..."

# Delete VenafiInstall CR
kubectl -n "${K8S_NAMESPACE}" delete VenafiInstall cyberark-cm-for-kubernetes --ignore-not-found || true

# Delete VenafiInstall CR
kubectl -n "${K8S_NAMESPACE}" delete VenafiInstall ccm-istio-csr-install  --ignore-not-found || true

# Delete Subscription
kubectl -n "${K8S_NAMESPACE}" delete subscription vcp-operator --ignore-not-found || true

# Delete OperatorGroup
kubectl -n "${K8S_NAMESPACE}" delete operatorgroup cyberark-operator-group --ignore-not-found || true

# Optionally delete the installed CSV (safely)
CSV_NAME=$(kubectl get csv -n "${K8S_NAMESPACE}" -o jsonpath='{.items[?(@.metadata.name=="vcp-operator.*")].metadata.name}' 2>/dev/null || true)
if [[ -n "$CSV_NAME" ]]; then
  echo "[clean] 🗑️ Deleting installed CSV: $CSV_NAME"
  kubectl delete csv "$CSV_NAME" -n "${K8S_NAMESPACE}" --ignore-not-found || true
fi

# (Optional) Remove CRDs installed by the operator
# echo "[clean] (optional) Deleting operator-managed CRDs"
# kubectl get crds | grep 'installer.venafi.com\|venafi.com' | awk '{print $1}' | xargs -r kubectl delete crd --ignore-not-found

# Read service account client IDs
CYBR_AGENT_SA_CLIENT_ID="$(<"${INSTALL_DIR}/cybr_mis_agent_client_id.txt")"
CYBR_FIREFLY_SA_CLIENT_ID="$(<"${INSTALL_DIR}/cybr_mis_firefly_client_id.txt")"
# Optionally allow override of trust domain
: "${CSI_DRIVER_SPIFFE_TRUST_DOMAIN:=cluster.local}"

VENAFI_KUBERNETES_AGENT_CLIENT_ID="${CYBR_AGENT_SA_CLIENT_ID}" \
FIREFLY_VENAFI_CLIENT_ID="${CYBR_FIREFLY_SA_CLIENT_ID}" \
CSI_DRIVER_SPIFFE_TRUST_DOMAIN="${CSI_DRIVER_SPIFFE_TRUST_DOMAIN}" \
venctl components kubernetes manifest tool destroy --file "${INSTALL_DIR}/venafi-manifests.yaml" || true

for ns in sandbox cyberark; do
  echo "[clean] Deleting namespace: ${ns}"
  kubectl delete namespace "$ns" --ignore-not-found || true
done

kubectl get crds | grep 'jetstack.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true
kubectl get crds | grep 'cert-manager.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true

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


### Let's attempt to retire and delete the sample certificates in CyberArk Certificate Manager 
echo "[clean] 🧼 Retiring and deleting sample certificates from CyberArk Certificate Manager..."

# Certificate names to target (these match .certificateName in the API)
# Some of these are certs we created when create-sample-data was run. 
# The webhook certs are part of the install and they show up in the inventory

DEMO_CERT_NAMES=(
  "expiry-eddie.svc.cluster.local"
  "unmanaged-kid.svc.cluster.local"
  "Phantom RSA CA"
  "cipher-snake.svc.cluster.local"
  "ghost-rider.svc.cluster.local"
  "trust-manager.cyberark.svc"
  "cert-manager-webhook-ca"
  "approver-policy-webhook-ca"
)

# Step 1: Fetch all certs
ALL_CERTS_JSON=$(curl -sS -X GET "$CLOUD_URL/outagedetection/v1/certificates" \
  -H "accept: application/json" \
  -H "tppl-api-key: $CYBR_CLOUD_API_KEY")

if [[ -z "$ALL_CERTS_JSON" || "$ALL_CERTS_JSON" == "null" ]]; then
  echo "[clean] ❌ Failed to retrieve certificate list or empty response."
  exit 1
fi

MATCHING_IDS=()

# Step 2: Find cert IDs by matching names
for cert_name in "${DEMO_CERT_NAMES[@]}"; do
  ID=$(echo "$ALL_CERTS_JSON" | jq -r --arg name "$cert_name" '.certificates[]? | select(.certificateName == $name) | .id')
  if [[ -n "$ID" ]]; then
    echo "[clean] 🔎 Found certificate '$cert_name' with ID: $ID"
    MATCHING_IDS+=("$ID")
  else
    echo "[clean] ⚠️ Certificate '$cert_name' not found or already deleted"
  fi
done

if [[ ${#MATCHING_IDS[@]} -eq 0 ]]; then
  echo "[clean] ✅ No matching certificates to retire or delete."
  exit 0
fi

IDS_JSON=$(printf '%s\n' "${MATCHING_IDS[@]}" | jq -R . | jq -s .)

# Step 3 - Retire certificates
echo "[clean] ⏸ Retiring certificates..."

RESPONSE=$(curl -sS -w "%{http_code}" --fail \
  -X POST "$CLOUD_URL/outagedetection/v1/certificates/retirement" \
  -H "tppl-api-key: $CYBR_CLOUD_API_KEY" \
  -H "accept: application/json" \
  -H "content-type: application/json" \
  --data "{\"certificateIds\": $IDS_JSON}" \
  -o /tmp/retire_response.json)

if [[ "$RESPONSE" != "200" && "$RESPONSE" != "204" ]]; then
  echo "[clean] ❌ Retirement failed (HTTP $RESPONSE)"
  echo "[clean] Response:"
  cat /tmp/retire_response.json | jq .
  exit 1
else
  echo "[clean] ✅ Certificates retired"
fi

# Step 4 - Delete certificates
echo "[clean] 🗑 Deleting retired certificates..."

RESPONSE=$(curl -sS -w "%{http_code}" --fail \
  -X POST "$CLOUD_URL/outagedetection/v1/certificates/deletion" \
  -H "tppl-api-key: $CYBR_CLOUD_API_KEY" \
  -H "accept: application/json" \
  -H "content-type: application/json" \
  --data "{\"certificateIds\": $IDS_JSON}" \
  -o /tmp/delete_response.json)

if [[ "$RESPONSE" != "200" && "$RESPONSE" != "204" ]]; then
  echo "[clean] ❌ Deletion failed (HTTP $RESPONSE)"
  echo "[clean] Response:"
  cat /tmp/delete_response.json | jq .
  exit 1
else
  echo "[clean] ✅ Certificates deleted"
fi


# Clean up generated CyberArk install artifacts
if [[ "${PURGE_ARTIFACTS:-}" == "true" ]]; then
  echo "[clean] Removing generated artifacts at: ${ARTIFACTS_DIR}"
  rm -rf "${ARTIFACTS_DIR}"
fi

echo "[clean] ✅ Full demo environment teardown complete."
