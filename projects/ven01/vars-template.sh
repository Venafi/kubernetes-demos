# Env settings to access Venafi

#export VEN_CLOUD_API_KEY :=<need this for discovery later>
#export VEN_USER_NAME :=<username> # E.g local:brad
#export VEN_USER_PASS :=<password>
#export VEN_API_CLIENT :=cert-manager.io
export VEN_SERVER_URL :=https://my-tpp.server.com/vedsdk
export VEN_ACCESS_TOKEN :=replace-with-access-token
#export VEN_PUBLIC_CA1 := "SKI\\\\Certificates\\\\Kubernetes" # E.g. Certificates\\Kubernetes\\Public1
export VEN_PRIVATE_CA1 := "SKI\\Certificates\\ICA30-new" # E.g. Certificates\\Kubernetes\\Private1 
export VEN_TPP_CA_BUNDLE_PEM_FILE :=./venafi-tpp-server-ca.pem


# Env settings to access AWS PCA
export VEN_AWS_PCA_ARN :=arn:aws:acm-pca:us-east-1:11111111111:certificate-authority/aaaaaaaa-1234-5678-abcd-aaaabbbbcccc
export VEN_AWS_PCA_REGION :=us-east-1

# Access key and secret access key required only if using secret to access PCA
# If using IRSA, the service account name must be provided
############################### Set only if NOT using IRSA ###############################
export VEN_AWS_PCA_ACCESS_KEY :=
export VEN_AWS_PCA_SECRET_ACCESS_KEY :=

############################### Set only if using IRSA ###############################
# Kubernetes service account name used for establishing trust relationship with AWS
# Requires changing templates/helm/aws-pca-issuer.yaml before install. 
# Also requires changing templates/pca/aws-pca-issuer.yaml to remove reference to secret
# ACCESS_KEY and SECRET_ACCESS_KEY is not required. 
# Assumes you have created all the required things (IAM policy, trust in your AWS account)
export VEN_AWS_PCA_IRSA_K8S_SA_NAME :=awspca-issuer-svc-account
export VEN_AWS_PCA_IRSA_POLICY_AND_ROLE_PREFIX :=ski-awspca
export VEN_AWS_PCA_ACCESS_POLICY_ARN :=arn:aws:iam::11111111111:policy/${VEN_AWS_PCA_IRSA_POLICY_AND_ROLE_PREFIX}-access-policy
export VEN_EKS_CLUSTER_NAME :=ski-test3
export VEN_EKS_CLUSTER_REGION :=us-east-2