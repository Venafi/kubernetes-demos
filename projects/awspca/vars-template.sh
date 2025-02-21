# AWS Profile to use for access
export CYBR_AWS_PROFILE :=profile-name

# Env settings to access AWS PCA
export CYBR_AWS_PCA_ARN :=arn:aws:acm-pca:us-east-1:111111111111:certificate-authority/aaaaaaaa-1234-5678-abcd-aaaabbbbcccc
export CYBR_AWS_PCA_REGION :=us-east-1

############################### Set only if using IRSA ###############################
# Assumes you have created all the required things (IAM policy, trust in your AWS account)
# Install with IRSA uses templates/helm/aws-pca-issuer-irsa.yaml for Helm install. 
export CYBR_AWS_PCA_IRSA_K8S_SA_NAME :=awspca-issuer-svc-account
export CYBR_AWS_PCA_IRSA_POLICY_AND_ROLE_PREFIX :=ski-awspca
export CYBR_AWS_PCA_ACCESS_POLICY_ARN :=arn:aws:iam::111111111111:policy/${CYBR_AWS_PCA_IRSA_POLICY_AND_ROLE_PREFIX}-access-policy
export CYBR_EKS_CLUSTER_NAME :=ski-eks
export CYBR_EKS_CLUSTER_REGION :=us-east-1

############################### Set only if NOT using IRSA ###############################
# Access key and secret access key required only if using secret to access PCA
# If using IRSA, ignore this, leave the access key and secret empty
# Install with secret uses templates/helm/aws-pca-issuer.yaml for Helm install.
export CYBR_AWS_PCA_ACCESS_KEY :=
export CYBR_AWS_PCA_SECRET_ACCESS_KEY :=
