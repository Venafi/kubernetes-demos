export JS_ENTERPRISE_CREDENTIALS_FILE :=~/GitHub/demos/js-enterprise-credentials.json

###########################
# Venafi Specific Variables
###########################

# Venafi TPP access token. You must have the Venafi platform up and running
export JS_VENAFI_TPP_ACCESS_TOKEN :=REPLACE-ME

export JS_VENAFI_TPP_URL :=REPLACE-ME # E.g. https://tpp.mydomain.com/vedsdk

#Reference to file that contains CA bundle in PEM format. This is the certchain to tpp.mydomain.com. venafi-tpp-server-ca.pem is in .gitignore 
export JS_VENAFI_TPP_CA_BUNDLE_PEM_FILE :=~/GitHub/demos/venafi-tpp-server-ca.pem
#Base64 encoding of the above
export JS_VENAFI_TPP_BASE64_ENCODED_CACERT :=REPLACE_ME
export JS_VENAFI_TPP_ZONE_PUBLIC_CA1 := REPLACE-ME # E.g. Certificates\\\\Kubernetes\\\\Public1
export JS_VENAFI_TPP_ZONE_PUBLIC_CA2 := REPLACE-ME # E.g. Certificates\\\\Kubernetes\\\\Public2

#Reference to file that contains CA bundle in PEM format for Private PKI. This is the root CA for PKI referenced in PRIVATE_CA$. 
#venafi-msca-ica-root.pem is in .gitignore 
export JS_VENAFI_INTERMEDIATE_CA_ROOT_PEM_FILE :=~/GitHub/demos/venafi-msca-ica-root.pem
export JS_VENAFI_TPP_ZONE_PRIVATE_CA1 := REPLACE-ME # E.g. Certificates\\Kubernetes\\Private1
export JS_VENAFI_TPP_ZONE_PRIVATE_CA2 := REPLACE-ME # E.g. Certificates\\Kubernetes\\Private2

#Location to sync certificates between Kubernetes and Venafi TPP
export JS_VENAFI_CERT_SYNC_POLICY_FOLDER := REPLACE-ME # E.g. Certificates\\\\Kubernetes\\\\Discovered

# Venafi API Key. Register for an account on ui.venafi.cloud for a key.
export JS_VENAFI_CLOUD_API_KEY :=REPLACE-ME

# Figure out escaping on your own !!. Using \\ here. Had to use \\\\ For Venafi TPP.
export JS_VENAFI_CLOUD_PUBLIC_ZONE_ID1 :=Demo\\demo
export JS_VENAFI_CLOUD_PUBLIC_ZONE_ID2 :=Demo\\demo

# Venafi Zone ID for CSI driver specific usecases.
# Due to escaping \\ becomes one \, so Demo\\\\demo becomes Demo\\demo
export JS_VENAFI_CLOUD_PRIVATE_ZONE_ID1 :=Demo\\\\demo
export JS_VENAFI_CLOUD_PRIVATE_ZONE_ID2 :=Demo\\\\demo

export JS_VENAFI_TPP_USERNAME := REPLACE-ME # E.g. user1
export JS_VENAFI_TPP_PASSWORD := REPLACE-ME # E.g. userpass

# Email for creating docker registry secret that holds Jetstack Secure enterprise access token
export JS_DOCKER_EMAIL :=REPLACE_ME
export JS_EMAIL_ID_FOR_LE_CERT :=${JS_DOCKER_EMAIL} #for LE certs

#DNS Specific variables
export JS_JETSTACKER_DOMAIN_NAME :=REPLACE_ME
export JS_K8S_CLUSTER_NAME :=jetstack-secure-demo-01

#Component versions
# cert-manager helm chart version
export JS_CERT_MANAGER_VERSION :=v1.9.1
# cert-discovery-venafi helm chart version
export JS_VENAFI_CERT_SYNC_VERSION :=v0.1.0
# approver policy helm chart version
export JS_POLICY_APPROVER_VERSION :=v0.4.0-0
# Isolated issuer version
export JS_ISOLATED_ISSUER_VERSION :=v0.0.1-alpha.2
# cert-manager-CSI-driver version helm chart version
export JS_CERT_MANAGER_CSI_DRIVER_VERSION :=v0.4.2
# cert-manager-CSI-driver-SPIFFE version helm chart version
export JS_CERT_MANAGER_CSI_DRIVER_SPIFFE_VERSION :=v0.2.2
# cert-manager-istio-csr version helm chart version
export JS_CERT_MANAGER_ISTIO_CSR_VERSION :=v0.5.0
# Istio version
export JS_ISTIO_VERSION :=1.14.1
export JS_ISTIO_SHORT_VERSION :=1.14

# Jetstack Secure common settings
export JS_CLUSTER_TRUST_DOMAIN_NAME :=jetstack-dev
export JS_WORKLOAD_CERT_DURATION :=1h
export JS_ISOLATED_ISSUER_BINARY :=~/Downloads/isolated-issuer-darwin-arm64/isolated-issuer

# CSI Driver SPIFFE Cluster Issuer Name. This will be a cluster issuer
# For namespaced issuer, change the HelmChart to define Issuer kind and also update the signer name
export JS_CERT_MANAGER_CSI_DRIVER_SPIFFE_ISSUER_NAME :=jetstack-spiffe-ca-issuer


#ISTIO CSR Helm Chart Settings
export JS_ISTIO_CSR_PRESERVE_CERT_REQUESTS :=true
export JS_ISTIO_CSR_CERT_RENEW_BEFORE :=30m
export JS_ISTIO_CSR_CERT_PROVIDER :=cert-manager-istio-csr.jetstack-secure.svc
#ISTIO CSR Helm Chart Settings

#Google CAS Specific Settings 
export JS_GCP_PROJECT_ID :=REPLACE_ME
export JS_GCP_ZONE :=REPLACE_ME
export JS_GCP_REGION :=us-central1


export JS_GCP_CAS_POOL_TIER :=devops
export JS_GCP_CAS_POOL_NAME :=my-ca-pool
export JS_GCP_CAS_NAME :=my-google-cas

#AWS Specific Variables
export JS_AWS_PROFILE_NAME :=REPLACE_ME #set to none to use default
export JS_AWS_REGION :=us-east-1
export JS_AWS_PCA_ACCESS_KEY :=REPLACE_ME
export JS_AWS_PCA_SECRET_ACCESS_KEY :=REPLACE_ME
# arn:aws:acm-pca:us-east-2:1234567890000:certificate-authority/eeddd208-aa3b-bb4b-cc2c-zzzyyyxxxwwww
export JS_AWS_PCA_ARN :=REPLACE_ME

