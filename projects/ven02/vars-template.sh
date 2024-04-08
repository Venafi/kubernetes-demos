# Env settings to access Venafi

export VEN_CLOUD_API_KEY :=<need this to create image registry secret>
#export VEN_USER_NAME :=<username> # E.g local:brad
#export VEN_USER_PASS :=<password>
#export VEN_API_CLIENT :=cert-manager.io
export VEN_SERVER_URL :=https://my-tpp.server.com/vedsdk
export VEN_ACCESS_TOKEN :=replace-with-access-token
#export VEN_PUBLIC_CA1 := "SKI\\\\Certificates\\\\Kubernetes" # E.g. Certificates\\Kubernetes\\Public1
export VEN_PRIVATE_CA1 := "SKI\\Certificates\\ICA30-new" # E.g. Certificates\\Kubernetes\\Private1 
export VEN_TPP_CA_BUNDLE_PEM_FILE :=./venafi-tpp-server-ca.pem
