#!/bin/bash
set -euo pipefail

source ./env-vars.sh

create_service_account() {
  echo "TODO - Add venctl iam service-accounts create when supported for federated accounts."
  echo "Look at the README to create using the UI"
  echo "There are API's available to create them.. just lazy to stich them together !"
}

install_agent() {

  echo "Installing CyberArk Certificate Manager Kubernetes Agent with client ID: $CYBR_SVC_AC_CLIENT_ID"

  helm upgrade --install ccm-kubernetes-agent oci://registry.venafi.cloud/charts/venafi-kubernetes-agent \
    --namespace "${KUBERNETES_NAMESPACE}" \
    --set authentication.venafiConnection.enabled="true" \
    --set authentication.venafiConnection.name="venafi-connection" \
    --set authentication.venafiConnection.namespace="${KUBERNETES_NAMESPACE}" \
    --set crds.venafiConnection.include=true \
    --set config.clusterName="${CLUSTER_NAME}" \
    --set config.clusterDescription="${CLUSTER_DESCRIPTION}" \
    --set config.clientId="${CYBR_SVC_AC_CLIENT_ID}" \
    --set serviceAccount.name="${KUBERNETES_SVC_ACCOUNT}" \
    --version ${CCM_AGENT_VERSION} \
    --create-namespace

  echo "Helm install completed. Creating RBAC and Connection resources..."

  cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cyberark-agent-token-create-role
  namespace: ${KUBERNETES_NAMESPACE}
rules:
- apiGroups: [ "" ]
  resources: [ "serviceaccounts/token" ]
  verbs: [ "create" ]
  resourceNames: [ "${KUBERNETES_SVC_ACCOUNT}" ]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cyberark-agent-token-create-role-binding
  namespace: ${KUBERNETES_NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cyberark-agent-token-create-role
subjects:
- kind: ServiceAccount
  name: venafi-connection
  namespace: ${KUBERNETES_NAMESPACE}

---
apiVersion: jetstack.io/v1alpha1
kind: VenafiConnection
metadata:
  name: venafi-connection
  namespace: ${KUBERNETES_NAMESPACE}
spec:
  vcp:
    url: https://api.venafi.cloud
    accessToken:
    - serviceAccountToken:
        name: ${KUBERNETES_SVC_ACCOUNT}
        audiences: [ "${CYBR_AUDIENCE}" ]
    - vcpOAuth:
        tenantID: ${CYBR_CLOUD_TENANT_ID}
EOF

  echo "Agent installation and configuration complete."
}

clean() {
  echo "Starting cleanup..."
  echo "Cleaning up Kubernetes resources..."
  kubectl delete VenafiConnection venafi-connection -n ${KUBERNETES_NAMESPACE} || true
  kubectl delete RoleBinding cyberark-agent-token-create-role-binding -n ${KUBERNETES_NAMESPACE} || true
  kubectl delete Role cyberark-agent-token-create-role -n ${KUBERNETES_NAMESPACE} || true
  helm uninstall ccm-kubernetes-agent -n ${KUBERNETES_NAMESPACE} || true
  kubectl delete namespace ${KUBERNETES_NAMESPACE} || true

  echo "Cleanup complete."
}

case "${1:-}" in
  create-service-account)
    create_service_account
    ;;
  install-agent)
    install_agent
    ;;
  clean)
    clean
    ;;
  *)
    echo "Usage: $0 {create-service-account|install-agent|clean}"
    exit 1
    ;;
esac
