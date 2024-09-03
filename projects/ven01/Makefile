MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean
SHELL := /bin/sh

################### demo POC Scripts ################
 # Include personal settings
 include vars.sh

########################################################################################################################
#  Review each command in the targets. 
########################################################################################################################

#Suffix for auto generated resources
_gen_timestamp:
	@echo $$(date +%S%H%M%d%m) > artifacts/resource-suffix.txt

RESOURCE_SUFFIX ?= $(shell cat artifacts/resource-suffix.txt)

######## STEP 0 ##############
# Install venctl if the preferred mode of interacting with Venafi Control Plane is CLI. This will install
# venctl in /usr/local/bin . Tested on MacOS ARM
install-venctl:
	@curl -sSfL https://dl.venafi.cloud/venctl/latest/installer.sh | bash

_init: mkdirs _gen_timestamp create-vcp-service-account create-namespaces configure-namespace

init-cloud: _init setup-cloud-config

######## STEP 1 ##############
step1: init-dc 

init-dc: _init setup-datacenter-config

mkdirs:
	@rm -rf artifacts
	@mkdir -p artifacts/venafi-install
	@mkdir -p artifacts/config
	@mkdir -p artifacts/samples


create-vcp-service-account: create-sa-for-discovery create-sa-for-registry create-sa-for-firefly

####################### BEGIN - Targets to create Venafi Kubernetes Agent Service Account and secret ####################### 
create-sa-for-discovery:
	@echo "skipping for this poc"
	
create-discovery-secret: _transform_agent_secret_to_yaml
	@echo "skipping for this poc"

_transform_agent_secret_to_yaml:
	@echo "skipping for this poc"

####################### END  - Targets to create Venafi Kubernetes Agent Service Account and secret ####################### 

####################### BEGIN - Targets to create Venafi Registry Service Account and secret ####################### 

create-sa-for-registry:
	@echo "skipping for this poc"

create-registry-secret: _transform_registry_secret_to_yaml
	@echo "Credentials for venafi registry"
	@kubectl -n venafi apply -f registry/venafi_registry_secret.yaml || true

_transform_registry_secret_to_yaml:
	@echo "skipping for this poc"

####################### END - Targets to create Venafi Registry Service Account and secret ####################### 

####################### BEGIN - Targets to create Venafi Firefly Service Account and secret ####################### 

create-sa-for-firefly:
	@echo "skipping for this poc"

create-firefly-secret:
	@echo "skipping for this poc"

####################### END - Targets to create Venafi Firefly Service Account and secret ####################### 

create-namespaces:
	@kubectl apply -f namespaces/venafi.yaml
	@kubectl apply -f namespaces/sandbox.yaml

configure-namespace: create-registry-secret create-discovery-secret create-firefly-secret

######## STEP 2 ##############
step2: generate-venafi-manifests

generate-venafi-manifests:
	@echo "Generating Venafi Helm manifests for installation"
	@venctl components kubernetes manifest generate \
		--namespace venafi \
		--cert-manager \
		--cert-manager-version v1.14.5 \
		--approver-policy-enterprise \
		--approver-policy-enterprise-version v0.16.0 \
		--venafi-enhanced-issuer \
		--venafi-enhanced-issuer-version v0.13.3 \
		--venafi-enhanced-issuer-values-files vei-values.yaml \
		--venafi-connection \
		--venafi-connection-version v0.0.20 \
		--image-pull-secret-names venafi-image-pull-secret  > artifacts/venafi-install/venafi-manifests.yaml

######## STEP 3 ##############
step3: install 

install:
	@venctl components kubernetes manifest tool sync --file artifacts/venafi-install/venafi-manifests.yaml 

un-install:
	@venctl components kubernetes manifest tool destroy --file artifacts/venafi-install/venafi-manifests.yaml 

generate-static-manifests:
	@echo "Generating static manifests if that's your preferred option"
	@venctl components kubernetes manifest tool template --file artifacts/venafi-install/venafi-manifests.yaml > artifacts/venafi-install/kubernetes-manifests.yaml

################################### BEGIN Venafi Cloud Targets #####################################
setup-cloud-config: create-agent-config-for-cloud create-vei-config-for-cloud

create-vei-config-for-cloud:
	@echo "skipping for this poc"

create-agent-config-for-cloud:
	@echo "skipping for this poc"

_create-venafi-cloud-access-secret: 
	
_create-venafi-cloud-connection-with-access-token:
	
create-venafi-cloud-cluster-issuer: _create-rbac-for-connections _create-venafi-cloud-access-secret _create-venafi-cloud-connection-with-access-token
	@echo "skipping for this poc"

################################### END Venafi Cloud Targets #####################################

####### BEGIN - COMMON TO DC AND CLOUD #######

_create-rbac-for-connections:
	@kubectl apply -f templates/common/venafi-connection-rbac.yaml

######## STEP 4 ##############
step4: create-certificate-policy

create-certificate-policy:
	@kubectl apply -f templates/common/cert-policy-and-rbac.yaml

####### END - COMMON TO DC AND CLOUD #######

################################### BEGIN Venafi Data center Targets #####################################

######## STEP 5 ##############
step5: create-venafi-tpp-cluster-issuer

create-venafi-tpp-cluster-issuer: _create-rbac-for-connections _create-venafi-tpp-access-secret _create-venafi-tpp-connection-with-access-token
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/dc/venafi-tpp-cluster-issuer.yaml \
     > artifacts/config/venafi-tpp-cluster-issuer.yaml
	@kubectl apply -f artifacts/config/venafi-tpp-cluster-issuer.yaml


get-venafi-token:
	@vcert getcred --username ${VEN_USER_NAME} \
		           --password ${VEN_USER_PASS} \
				   -u ${VEN_SERVER_URL} \
				   --client-id ${VEN_API_CLIENT} \
				   --scope "certificate:manage,revoke" \
				   --format json | tee /tmp/token

setup-datacenter-config: create-venafi-tpp-trust-anchor create-agent-config-for-dc create-vei-config-for-dc

create-vei-config-for-dc:
	@cp templates/helm/datacenter-vei-values.yaml artifacts/venafi-install/vei-values.yaml 

create-agent-config-for-dc:
	@echo "skipping for this poc"

create-venafi-tpp-trust-anchor:
	@cp ${VEN_TPP_CA_BUNDLE_PEM_FILE} artifacts/config/venafi-server-ca.pem
	@kubectl create configmap venafi-tpp-ca-bundle --namespace='venafi' --from-file=ca.crt=artifacts/config/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

_create-venafi-tpp-access-secret: 
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/dc/venafi-tpp-secret.yaml \
     > artifacts/config/venafi-tpp-secret.yaml
	@kubectl apply -f artifacts/config/venafi-tpp-secret.yaml

_create-venafi-tpp-connection-with-access-token:
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/dc/venafi-tpp-connection.yaml \
     > artifacts/config/venafi-tpp-connection.yaml
	@kubectl apply -f artifacts/config/venafi-tpp-connection.yaml



################################### END Venafi Data center Targets #####################################

################################## SAMPLES ##################################

######## STEP 6 ##############
step6: create-sample-cert

create-sample-cert:
	@kubectl apply -f samples/sample-cert.yaml

check-sample-cert:
	@cmctl -n sandbox status certificate sample-cert01.svc.cluster.local
	@cmctl -n sandbox inspect secret sample-cert01.svc.cluster.local

renew-sample-cert:	
	@cmctl -n sandbox renew sample-cert01.svc.cluster.local

################################## SAMPLES ##################################

remove-cert:
	@kubectl delete -f samples/sample-cert.yaml || true
	@kubectl -n sandbox delete secret sample-cert01.svc.cluster.local || true

remove-policy:
	@kubectl delete -f templates/common/cert-policy-and-rbac.yaml || true

remove-issuer-resources: _remove-dc-issuer-resources _remove-cloud-issuer-resources _remove-common-issuer-resources 

_remove-dc-issuer-resources:
	@kubectl delete -f artifacts/config/venafi-tpp-cluster-issuer.yaml || true
	@kubectl delete -f artifacts/config/venafi-tpp-connection.yaml	|| true
	@kubectl delete -f artifacts/config/venafi-tpp-secret.yaml || true

_remove-cloud-issuer-resources:
	@kubectl delete -f artifacts/config/venafi-cloud-cluster-issuer.yaml || true
	@kubectl delete -f artifacts/config/venafi-cloud-connection.yaml	|| true
	@kubectl delete -f artifacts/config/venafi-cloud-secret.yaml || true
	
_remove-common-issuer-resources:
	@kubectl delete -f templates/common/venafi-connection-rbac.yaml || true

remove-secrets:
	@echo "skipping for this poc"

clean: remove-cert remove-policy remove-issuer-resources un-install remove-secrets
	@kubectl delete -f namespaces/venafi.yaml || true
	@kubectl delete -f namespaces/sandbox.yaml || true


############## STEP 7 Installing AWS PCA #####################

############################### AWS PCA with IRSA ############################### 
# STEP A
#Create an IAM OIDC Identity provider for the cluster. 
#https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html

# STEP B
# Create a IAM Access policy to allow access to AWS ACM PCA
# Review templates/pca/awspca-access-policy.json
create-awspca-access-policy:
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/pca/awspca-access-policy.json \
		> artifacts/config/awspca-access-policy.json
	@aws iam create-policy --policy-name ${VEN_AWS_PCA_IRSA_POLICY_AND_ROLE_PREFIX}-access-policy \
						   --policy-document file://artifacts/config/awspca-access-policy.json

# STEP C
# Create a IAM Service account that maps IAM Role to Kubernetes service account.
# If you have run this before and created a IAM svc account make sure to run delete-iam-svc-account if you deleted the kubernetes svc account.
create-iam-svc-account: 
	@eksctl create iamserviceaccount --name ${VEN_AWS_PCA_IRSA_K8S_SA_NAME} \
									 --namespace venafi \
									 --cluster ${VEN_EKS_CLUSTER_NAME} \
									 --region ${VEN_EKS_CLUSTER_REGION} \
									 --role-name ${VEN_AWS_PCA_IRSA_POLICY_AND_ROLE_PREFIX}-role \
									 --attach-policy-arn ${VEN_AWS_PCA_ACCESS_POLICY_ARN} \
									 --override-existing-serviceaccounts \
									 --approve

install-awspca: 
	@helm upgrade \
	    --install -f artifacts/venafi-install/aws-pca-issuer-values.yaml aws-privateca-issuer awspca/aws-privateca-issuer \
		--version v1.3.0 \
  		--namespace venafi \
		--wait		

_setup-aws-issuer-irsa-resources:
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/helm/aws-pca-issuer-irsa.yaml \
		> artifacts/venafi-install/aws-pca-issuer-values.yaml

create-aws-pca-issuer-with-irsa: _create_awspca_issuing_policy _setup-aws-issuer-irsa-resources install-awspca 
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/pca/aws-pca-issuer-irsa.yaml \
		> artifacts/config/aws-pca-issuer.yaml
	@kubectl apply -f artifacts/config/aws-pca-issuer.yaml

step7a: create-aws-pca-issuer-with-irsa

############################### AWS PCA with IRSA ############################### 

_create_awspca_issuing_policy:
	@kubectl apply -f aws/cert-policy-and-rbac.yaml

############################### AWS PCA with Access and Secret access key ############################### 
step7b: create-aws-pca-issuer

_create_awspca_secret:
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/pca/aws-secret.yaml \
		> artifacts/config/aws-secret.yaml
	@kubectl apply -f artifacts/config/aws-secret.yaml

_setup-aws-issuer-resources:
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/helm/aws-pca-issuer.yaml \
		> artifacts/venafi-install/aws-pca-issuer-values.yaml

create-aws-pca-issuer: _create_awspca_secret _setup-aws-issuer-resources _create_awspca_issuing_policy install-awspca
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/pca/aws-pca-issuer.yaml \
		> artifacts/config/aws-pca-issuer.yaml
	@kubectl apply -f artifacts/config/aws-pca-issuer.yaml

############################### AWS PCA with Access and Secret access key ############################### 

############## STEP 8 #####################
step8: create-sample-awspca-certs

create-sample-awspca-certs:
	@kubectl apply -f samples/sample-aws-pca-cert.yaml 

cleanup-aws-pca-resources:
	@kubectl delete -f aws/cert-policy-and-rbac.yaml || true
	@kubectl delete -f samples/sample-aws-pca-cert.yaml || true
	@kubectl delete -f artifacts/config/aws-pca-issuer.yaml || true 
	@kubectl delete -f artifacts/config/aws-secret.yaml || true
	@helm uninstall -n venafi aws-privateca-issuer || true

cleanall: cleanup-aws-pca-resources clean

#################### Helper IRSA Targets ################### 
## To redo in existing env, delete iam svc account 
delete-iam-svc-account:
	@eksctl delete iamserviceaccount --name ${VEN_AWS_PCA_IRSA_K8S_SA_NAME} --namespace venafi --cluster ${VEN_EKS_CLUSTER_NAME} --region ${VEN_EKS_CLUSTER_REGION} 