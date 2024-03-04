# Env settings to access Venafi

export VEN_CLOUD_API_KEY :=<your-cloud-api-key>
export VEN_SERVER_URL :=https://tpp.example.com/vedsdk
export VEN_ACCESS_TOKEN :=<your-venafi-access-token>
export VEN_PUBLIC_CA1 := "SKI\\\\Certificates\\\\Kubernetes" # E.g. Certificates\\Kubernetes\\Public1
#export VEN_PRIVATE_CA1 := "SKI\\\\Certificates\\\\ICA30-new" # E.g. Certificates\\Kubernetes\\Private1 
export VEN_PRIVATE_CA1 := "Store App\\venafi-builtin-ca-template" # E.g. Venafi Cloud App\\issuing-template 
export VEN_TPP_CA_BUNDLE_PEM_FILE :=./venafi-tpp-server-ca.pem


### Required only for service mesh usecase #####
export VEN_CONTAINER_REGISTRY :=private-registry.venafi.cloud
export VEN_ISTIO_CSR_VERSION :="v0.8.1"
export VEN_DOCKER_REGISTRY_SECRET :=venafi-image-pull-secret
#replace with 
export VEN_FIREFLY_ICA_ROOT_CA_PEM :=./venafi-cloud-built-in-root.pem
export VEN_DOMAIN_NAME_FOR_SAMPLE_APP :=example.com