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
	@echo $$(date +%S%H%M%d%m) > awspca-artifacts/resource-suffix.txt

RESOURCE_SUFFIX ?= $(shell cat awspca-artifacts/resource-suffix.txt)

######## STEP 0 ##############
# Install venctl if the preferred mode of interacting with Venafi Control Plane is CLI. This will install
# venctl in /usr/local/bin . Tested on MacOS ARM
install-venctl:
	@curl -sSfL https://dl.venafi.cloud/venctl/latest/installer.sh | bash

init: mkdirs _gen_timestamp create-namespaces

mkdirs:
	@rm -rf awspca-artifacts
	@mkdir -p awspca-artifacts/cyberark-install
	@mkdir -p awspca-artifacts/config
	@mkdir -p awspca-artifacts/samples

create-namespaces:
	@kubectl apply -f namespaces/cyberark.yaml
	@kubectl apply -f namespaces/sandbox.yaml

############################### AWS PCA with IRSA ############################### 
# STEP A
#Create an IAM OIDC Identity provider for the cluster. 
#https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html

# STEP B
# Create a IAM Access policy to allow access to AWS ACM PCA
# Review templates/pca/awspca-access-policy.json
create-awspca-access-policy:
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/pca/awspca-access-policy.json \
		> awspca-artifacts/config/awspca-access-policy.json
	@aws --profile ${CYBR_AWS_PROFILE} iam create-policy --policy-name ${CYBR_AWS_PCA_IRSA_POLICY_AND_ROLE_PREFIX}-access-policy \
						   --policy-document file://awspca-artifacts/config/awspca-access-policy.json

# STEP C
# Create a IAM Service account that maps IAM Role to Kubernetes service account.
# If you have run this before and created a IAM svc account make sure to run delete-iam-svc-account if you deleted the kubernetes svc account.
create-iam-svc-account: 
	@eksctl create iamserviceaccount --name ${CYBR_AWS_PCA_IRSA_K8S_SA_NAME} \
									 --namespace cyberark \
									 --cluster ${CYBR_EKS_CLUSTER_NAME} \
									 --region ${CYBR_EKS_CLUSTER_REGION} \
									 --role-name ${CYBR_AWS_PCA_IRSA_POLICY_AND_ROLE_PREFIX}-role \
									 --attach-policy-arn ${CYBR_AWS_PCA_ACCESS_POLICY_ARN} \
									 --override-existing-serviceaccounts \
									 --profile ${CYBR_AWS_PROFILE} \
									 --approve



generate-venafi-manifests:
	@echo "Generating Cyberark Helm manifests for installation"
	@venctl components kubernetes manifest generate \
		--namespace cyberark \
		--aws-privateca-issuer \
		--aws-privateca-issuer-values-files aws-pca-issuer-values.yaml \
		--ignore-dependencies  > awspca-artifacts/cyberark-install/awspca-manifests.yaml

install:
	@venctl components kubernetes manifest tool sync --file awspca-artifacts/cyberark-install/awspca-manifests.yaml

generate-static-manifests:
	@echo "Generating static manifests if that's your preferred option"
	@venctl components kubernetes manifest tool template --file awspca-artifacts/cyberark-install/venafi-manifests.yaml > awspca-artifacts/cyberark-install/kubernetes-manifests.yaml


# This is required if policy approver is installed. If cert-manager approver controller automatically approves all certificate requests then this is not required.
create_certificate_policy_for_awspca:
	@kubectl apply -f policy/cert-policy-and-rbac.yaml

install-awspca: generate-venafi-manifests install

########  BEGIN - If you prefer Helm install instead of venctl ###################
install-awspca-helm: 
	@helm upgrade \
	    --install -f awspca-artifacts/cyberark-install/aws-pca-issuer-values.yaml aws-privateca-issuer awspca/aws-privateca-issuer \
		--version v1.4.0 \
  		--namespace cyberark \
		--wait		

helm-uninstall:
	@helm uninstall -n cyberark aws-privateca-issuer || true

######## END - If you prefer Helm install instead of venctl ###################

############################### BEGIN - AWS PCA with IRSA ############################### 
create-aws-pca-issuer-with-irsa: _setup-aws-issuer-irsa-resources install-awspca
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/pca/aws-pca-issuer-irsa.yaml \
		> awspca-artifacts/config/aws-pca-issuer.yaml
	@kubectl apply -f awspca-artifacts/config/aws-pca-issuer.yaml

_setup-aws-issuer-irsa-resources:
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/helm/aws-pca-issuer-irsa.yaml \
		> awspca-artifacts/cyberark-install/aws-pca-issuer-values.yaml

############################### END - AWS PCA with IRSA ############################### 

############################### BEGIN - AWS PCA with Access and Secret access key ############################### 

create-aws-pca-issuer-access-key: _create_awspca_secret _setup-aws-issuer-resources install-awspca
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/pca/aws-pca-issuer.yaml \
		> awspca-artifacts/config/aws-pca-issuer.yaml
	@kubectl apply -f awspca-artifacts/config/aws-pca-issuer.yaml

_create_awspca_secret:
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/pca/aws-secret.yaml \
		> awspca-artifacts/config/aws-secret.yaml
	@kubectl apply -f awspca-artifacts/config/aws-secret.yaml

_setup-aws-issuer-resources:
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/helm/aws-pca-issuer.yaml \
		> awspca-artifacts/cyberark-install/aws-pca-issuer-values.yaml

############################### END - AWS PCA with Access and Secret access key ############################### 

############## sample certs #####################

create-sample-awspca-certs:
	@kubectl apply -f samples/sample-aws-pca-cert.yaml 

cleanup-aws-pca-resources:
	@kubectl delete -f samples/sample-aws-pca-cert.yaml || true
	@kubectl delete -f policy/cert-policy-and-rbac.yaml || true
	@kubectl delete -f awspca-artifacts/config/aws-pca-issuer.yaml || true 
	@kubectl delete -f awspca-artifacts/config/aws-secret.yaml || true
		
un-install:
	@venctl components kubernetes manifest tool destroy --file awspca-artifacts/cyberark-install/awspca-manifests.yaml

clean: cleanup-aws-pca-resources un-install
	@kubectl get crds | grep 'awspca.cert-manager.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true

#################### Helper IRSA Targets ################### 
## To redo in existing env, delete iam svc account 
delete-iam-svc-account:
	@eksctl --profile ${CYBR_AWS_PROFILE} delete iamserviceaccount --name ${CYBR_AWS_PCA_IRSA_K8S_SA_NAME} --namespace cyberark --cluster ${CYBR_EKS_CLUSTER_NAME} --region ${CYBR_EKS_CLUSTER_REGION} 