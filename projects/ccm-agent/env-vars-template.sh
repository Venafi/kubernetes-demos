# env-vars.sh

export CYBR_CLOUD_API_KEY="af7cd59f-352c-4379-8978-e79510101f3a"
export CYBR_CLOUD_TENANT_ID="891e1f21-dc80-11ec-a787-89187550eb51"
export CYBR_SVC_AC_CLIENT_ID="a07ef0f9-6d80-11f0-9c17-361d760ab5a1"

export CLUSTER_NAME="my-cluster01"
export CLUSTER_DESCRIPTION="myc-cluster01 description"

# Service Account config for Cyberark Certificate Manager
#export CYBR_OIDC_ISSUER_URL="https://oidc.eks.<region>.amazonaws.com/id/foo-bar"
#export CYBR_JWKS_URI="${CYBR_OIDC_ISSUER_URL}/keys"
export CYBR_AUDIENCE="api.venafi.cloud"
#export CYBR_SERVICE_ACCOUNT_NAME="discovery-with-oidc1"
#export CYBR_SCOPE="kubernetes-discovery"
export KUBERNETES_NAMESPACE="cyberark"
export KUBERNETES_SVC_ACCOUNT="cyberark-kubernetes-agent"
export CCM_AGENT_VERSION="v1.6.0"
#export CYBR_SUBJECT="system:serviceaccount:${KUBERNETES_NAMESPACE}:${KUBERNETES_SVC_ACCOUNT}"
