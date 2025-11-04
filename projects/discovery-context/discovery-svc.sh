#!/bin/bash
set -euo pipefail

source ./env-vars.sh

create_service_user() {
  echo "Create a CyberArk Discovery Service User via CyberArk UI or API."
}

install_agent() {

  echo "Installing CyberArk Discovery Service Agent"

  kubectl create namespace "${KUBERNETES_NAMESPACE}" \
    --dry-run=client --save-config=true -o yaml | kubectl apply -f -

  kubectl create secret generic agent-credentials \
    --namespace="${KUBERNETES_NAMESPACE}" \
    --from-literal=ARK_USERNAME="${CYBR_ARK_USERNAME}" \
    --from-literal=ARK_SECRET="${CYBR_ARK_SECRET}" \
    --from-literal=ARK_SUBDOMAIN="${CYBR_ARK_SUBDOMAIN}" \
    --dry-run=client --save-config=true -o yaml | kubectl apply -f -

  helm upgrade --install cyberark-discovery-agent "${CYBR_ARK_CHART_REPOSITORY}" \
    --namespace "${KUBERNETES_NAMESPACE}" \
    --set image.repository="${CYBR_ARK_IMAGE_REPOSITORY}" \
    --set config.clusterName="${CLUSTER_NAME}" \
    --set config.clusterDescription="${CLUSTER_DESCRIPTION}" \
    --set serviceAccount.name="${KUBERNETES_SVC_ACCOUNT}" \
    --version ${DISCOVERY_AGENT_VERSION} \
    --create-namespace

  echo "Helm install completed. CyberArk Discovery Service Agent is being deployed."

}

clean() {
  echo "Starting cleanup..."
  echo "Cleaning up Kubernetes resources..."
  helm uninstall cyberark-discovery-agent -n ${KUBERNETES_NAMESPACE} || true
  kubectl delete namespace ${KUBERNETES_NAMESPACE} || true

  echo "Cleanup complete."
}

case "${1:-}" in
  create-service-user)
    create_service_user
    ;;
  install-agent)
    install_agent
    ;;
  clean)
    clean
    ;;
  *)
    echo "Usage: $0 {create-service-user|install-agent|clean}"
    exit 1
    ;;
esac
