# env-vars.sh

export CYBR_CLOUD_API_KEY="REPLACE_WITH_API_KEY"
export CYBR_CLOUD_TENANT_ID="REPLACE_WITH_TENANT_ID"
export CYBR_SVC_AC_CLIENT_ID="REPLACE_WITH_SVC_CLIENT_ID"

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
