# Env settings to access Venafi

export VEN_CLOUD_API_KEY :=REPLACE_WITH_CLOUD_API_KEY
export VEN_ZONE_PRIVATE_CA :="Cloud App\\venafi-builtin" # E.g. Certificates\\Private-CA OR Venafi Cloud App\\issuing-template 
export VEN_TEAM_NAME :=platform-admin

##### BEGIN Required only if using data center ######
export VEN_SERVER_URL :=https://venafi.example.com/vedsdk
export VEN_ACCESS_TOKEN :=REPLACE_WITH_TPP_ACCESS_TOKEN
# If using Data center and server uses a private CA.
export VEN_TPP_CA_BUNDLE_PEM_FILE :=./venafi-tpp-server-ca.pem
##### END Required only if using data center ######


### BEGIN - Required only for service mesh usecase #####
export VEN_ZONE_PUBLIC_CA :="My-Apps\\public-ca" # E.g. TPP-Certificates\\\\Public-CA OR Venafi Cloud App\\issuing-template 
export VEN_DOMAIN_FOR_SAMPLE_APP :=example.com
export VEN_AWS_ZONE :=foobar

export VEN_CLOUD_BUILTIN_ICA_ROOT_CA_PEM :=./venafi-cloud-built-in-root.pem
export VEN_CLOUD_ZKPKI_ICA_ROOT_CA_PEM :=./venafi-cloud-zkpki-root.pem

export VEN_TRUST_ANCHOR_ROOT_CA_PEM :=${VEN_CLOUD_BUILTIN_ICA_ROOT_CA_PEM}
#export VEN_TRUST_ANCHOR_ROOT_CA_PEM :=${VEN_CLOUD_ZKPKI_ICA_ROOT_CA_PEM}

### END - Required only for service mesh usecase #####