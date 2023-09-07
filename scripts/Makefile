MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean 
SHELL := /bin/sh

# Include personal settings
include ../settings.sh

## GCP Targets 
create-gke-cluster:
	@echo 'Creating GKE Cluster for ${JS_GCP_PROJECT_ID} in region ${JS_GCP_REGION}'
	@./gcp/gke-cluster.sh ${JS_GCP_PROJECT_ID} ${JS_GCP_REGION} ${JS_K8S_CLUSTER_NAME}

remove-gke-cluster:
	@gcloud container clusters delete ${JS_K8S_CLUSTER_NAME} --region ${JS_GCP_REGION}

create-google-cas:
	@./gcp/cas.sh ${JS_GCP_PROJECT_ID} ${JS_GCP_REGION} ${JS_JETSTACKER_DOMAIN_NAME} ${JS_GCP_CAS_NAME} ${JS_GCP_CAS_POOL_NAME} ${JS_GCP_CAS_POOL_TIER}

remove-google-cas:
	@./gcp/cas-delete.sh ${JS_GCP_PROJECT_ID} ${JS_GCP_REGION} ${JS_JETSTACKER_DOMAIN_NAME} ${JS_GCP_CAS_NAME} ${JS_GCP_CAS_POOL_NAME}

map-mesh-gateway-ip-to-dns:
	@rm -f transaction.yaml
	@./gcp/map-dns-to-gateway.sh ${JS_GCP_ZONE} ${JS_JETSTACKER_DOMAIN_NAME}


## AWS Targets

# Create EKS Cluster
create-eks-cluster:
	@echo 'Creating EKS Cluster creation with ${JS_AWS_PROFILE_NAME} in region ${JS_AWS_REGION}'
	@./aws/aws-cluster.sh ${JS_AWS_PROFILE_NAME} ${JS_AWS_REGION} ${JS_K8S_CLUSTER_NAME}

remove-eks-cluster:
ifeq ($(JS_AWS_PROFILE_NAME),none)
	@eksctl delete cluster --region ${JS_AWS_REGION} --name=${JS_K8S_CLUSTER_NAME}
else
	@eksctl delete cluster --profile ${JS_AWS_PROFILE_NAME} --region ${JS_AWS_REGION} --name=${JS_K8S_CLUSTER_NAME}
endif

create-aws-pca:
	@./aws/pca.sh ${AWS_PROFILE_NAME} ${REGION} ${K8S_CLUSTER_NAME} ${AWS_PCA_ARN}

remove-aws-pca:
	@echo "Nothing here"

