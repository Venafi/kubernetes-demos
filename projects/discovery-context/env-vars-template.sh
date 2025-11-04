# .env
# Temporary directory where resources for installation are created
export ARTIFACTS_DIR=$HOME/cert-artifacts
export NUM_SAMPLE_CERTS_TO_CREATE=3
export RESOURCE_SUFFIX="$(date +%S%H%M%d%m)"

export CYBR_ARK_USERNAME=REPLACE_WITH_SERVICE_ACCOUNT_EMAIL
export CYBR_ARK_SECRET=REPLACE_WITH_SERVICE_ACCOUNT_PASSWORD
export CYBR_ARK_SUBDOMAIN=REPLACE_WITH_CONJUR_SUBDOMAIN
#export CYBR_ARK_DISCOVERY_API=foo.bar

export KUBERNETES_NAMESPACE="cyberark"
export KUBERNETES_SVC_ACCOUNT="cyberark-kubernetes-agent"
export CYBR_ARK_CHART_REPOSITORY="oci://registry.venafi.cloud/charts/disco-agent"
export CYBR_ARK_IMAGE_REPOSITORY="registry.venafi.cloud/disco-agent/disco-agent"
export DISCOVERY_AGENT_VERSION="v1.7.0"
    
export CLUSTER_NAME="my-cluster01"
export CLUSTER_DESCRIPTION="my-cluster01 description"