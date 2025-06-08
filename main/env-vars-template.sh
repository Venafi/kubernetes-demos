# .env
export CYBR_TEAM_NAME=platform-admin
export CYBR_CLOUD_API_KEY=REPLACE_WITH_CLOUD_API_KEY
export CYBR_ZONE_PRIVATE_CA=CloudApps\\Default

export K8S_NAMESPACE=cyberark
export RESOURCE_SUFFIX="$(date +%S%H%M%d%m)"
# Temporary directory where resources for installation are created
export ARTIFACTS_DIR=$HOME/demo-artifacts

export CYBR_CLOUD_BUILTIN_ICA_ROOT_CA_PEM=./venafi-cloud-built-in-root.pem
export CYBR_CLOUD_ZKPKI_ICA_ROOT_CA_PEM=./venafi-cloud-zkpki-root.pem
export CYBR_DC_MSCA_ICA_ROOT_CA_PEM=./venafi-dc-msca-root.pem

export CYBR_TRUST_ANCHOR_ROOT_CA_PEM=${CYBR_CLOUD_BUILTIN_ICA_ROOT_CA_PEM}
#export CYBR_TRUST_ANCHOR_ROOT_CA_PEM=${CYBR_CLOUD_ZKPKI_ICA_ROOT_CA_PEM}
#export CYBR_TRUST_ANCHOR_ROOT_CA_PEM=${CYBR_DC_MSCA_ICA_ROOT_CA_PEM}

#Optional Settings for Istio Gateway configuration
# Zone that can issue public certificates
export CYBR_ZONE_PUBLIC_CA=CloudApps\\public-ca
# Domain name that you have access to. Sample App can be accessed using <resource-suffix>.<your-domain-name> 
export DOMAIN_NAME=foo.bar.com
# AWS Zone where entries will be made to map <domain-name> to Gateway external ip
export AWS_ZONE_ID=REPLACE_WITH_ZONEID

#Optional - If you prefer managing trust anchors using Conjur.
export CYBR_CONJUR_WORKLOAD_APIKEY=REPLACE_WITH_WORKLOAD_APIKEY