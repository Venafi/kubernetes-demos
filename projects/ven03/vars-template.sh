# Env settings to access Venafi

#Required
export VEN_CLOUD_API_KEY :=REPLACE_WITH_CLOUD_API_KEY
#Required
export VEN_ZONE_PRIVATE_CA :="Cloud App\\venafi-builtin" # E.g. Certificates\\Private-CA OR Venafi Cloud App\\issuing-template 
#export VEN_ZONE_PRIVATE_CA :="SKI-Apps\\\\ICA-30-Days" # E.g. Certificates\\Private-CA OR Venafi Cloud App\\issuing-template 
export VEN_TEAM_NAME :=platform-admin
export VEN_NAMESPACE :=cert-manager-operator

export VEN_REGISTRY_SECRET_YAML :=./venafi-registry-secret.yaml

export VEN_FIREFLY_PRIVATE_KEY :=./venafi-firefly-key.pem
export VEN_FIREFLY_SA_CLIENT_ID :=REPLACE_WITH_FF_SA_CLIENT_ID

