# .env
export CYBR_TEAM_NAME=REPLACE_WITH_TEAM_NAME
export CYBR_CLOUD_API_KEY=REPLACE_WITH_CLOUD_API_KEY
export CYBR_CLOUD_REGION=REPLACE_WITH_CLOUD_REGION # one of: eu, au, uk, ca, sg, us (default "us")
export CYBR_ZONE_PRIVATE_CA=CloudApps\\Default

export K8S_NAMESPACE=cyberark
export RESOURCE_SUFFIX="$(date +%S%H%M%d%m)"
# Temporary directory where resources for installation are created
export ARTIFACTS_DIR=$HOME/demo-artifacts

export CYBR_CLOUD_ZKPKI_ICA_ROOT_CA_PEM=./venafi-cloud-zkpki-root.pem
export CYBR_DC_MSCA_ICA_ROOT_CA_PEM=./venafi-dc-msca-root.pem

# No need to set Built In CA - It's automatically managed.
# Uncomment to use your own trust anchor. 
#export CYBR_TRUST_ANCHOR_ROOT_CA_PEM=${CYBR_CLOUD_ZKPKI_ICA_ROOT_CA_PEM}
#export CYBR_TRUST_ANCHOR_ROOT_CA_PEM=${CYBR_DC_MSCA_ICA_ROOT_CA_PEM}

#Optional Settings for Istio Gateway configuration
# Zone that can issue public certificates
export CYBR_ZONE_PUBLIC_CA=CloudApps\\public-ca
# Domain name that you have access to. Sample App can be accessed using <resource-suffix>.<your-domain-name> 
export DOMAIN_NAME=REPLACE_WITH_DOMAIN_NAME
# AWS Zone where entries will be made to map <domain-name> to Gateway external ip
export AWS_ZONE_ID=REPLACE_WITH_ZONEID
export AWS_PROFILE=REPLACE_WITH_AWS_PROFILE

# This for ensuring loadbalaners in cloud providers are not created with 0.0.0.0 access
export CIDR=REPLACE_WITH_LOCAL_CIDR


#Optional - If you prefer managing trust anchors using Conjur.
export CYBR_CONJUR_WORKLOAD_APIKEY=REPLACE_WITH_WORKLOAD_APIKEY