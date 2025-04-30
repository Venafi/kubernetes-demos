# Env settings to access Venafi

export CYBR_CLOUD_API_KEY :=REPLACE_WITH_CLOUD_API_KEY
export CYBR_ZONE_PRIVATE_CA :="Cloud App\\venafi-builtin" # E.g. Certificates\\Private-CA OR Venafi Cloud App\\issuing-template 
export CYBR_TEAM_NAME :=platform-admin

##### BEGIN Required only if using data center ######
export CYBR_SERVER_URL :=https://venafi.example.com/vedsdk
export CYBR_ACCESS_TOKEN :=REPLACE_WITH_TPP_ACCESS_TOKEN
# If using Data center and server uses a private CA.
export CYBR_TPP_CA_BUNDLE_PEM_FILE :=./venafi-tpp-server-ca.pem
##### END Required only if using data center ######


### BEGIN - Required only for service mesh usecase #####
export CYBR_ZONE_PUBLIC_CA :="My-Apps\\public-ca" # E.g. TPP-Certificates\\\\Public-CA OR Venafi Cloud App\\issuing-template 
export CYBR_DOMAIN_FOR_SAMPLE_APP :=example.com
export CYBR_AWS_ZONE :=foobar

export CYBR_CLOUD_BUILTIN_ICA_ROOT_CA_PEM :=./venafi-cloud-built-in-root.pem
export CYBR_CLOUD_ZKPKI_ICA_ROOT_CA_PEM :=./venafi-cloud-zkpki-root.pem
export CYBR_DC_MSCA_ICA_ROOT_CA_PEM :=./venafi-dc-msca-root.pem

export CYBR_TRUST_ANCHOR_ROOT_CA_PEM :=${CYBR_CLOUD_BUILTIN_ICA_ROOT_CA_PEM}
#export CYBR_TRUST_ANCHOR_ROOT_CA_PEM :=${CYBR_CLOUD_ZKPKI_ICA_ROOT_CA_PEM}
#export CYBR_TRUST_ANCHOR_ROOT_CA_PEM :=${CYBR_DC_MSCA_ICA_ROOT_CA_PEM}

### END - Required only for service mesh usecase #####