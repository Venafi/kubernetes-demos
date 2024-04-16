MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean 
SHELL := /bin/sh

# Include personal settings
 include ../cloud-settings.sh

create-cluster: create-gke-cluster

## GCP Targets 
create-gke-cluster:
	@echo 'Creating GKE Cluster for ${VEN_GCP_PROJECT_ID} in region ${VEN_GCP_REGION}'
	@./gcp/gke-cluster.sh ${VEN_GCP_PROJECT_ID} ${VEN_GCP_REGION} ${VEN_CLUSTER_NAME}

remove-gke-cluster:
	@gcloud container clusters delete ${VEN_CLUSTER_NAME} --region ${VEN_GCP_REGION}

create-google-cas:
	@./gcp/cas.sh ${VEN_GCP_PROJECT_ID} ${VEN_GCP_REGION} ${VEN_DOMAIN_NAME} ${VEN_GCP_CAS_NAME} ${VEN_GCP_CAS_POOL_NAME} ${VEN_GCP_CAS_POOL_TIER}

remove-google-cas:
	@./gcp/cas-delete.sh ${VEN_GCP_PROJECT_ID} ${VEN_GCP_REGION} ${VEN_DOMAIN_NAME} ${VEN_GCP_CAS_NAME} ${VEN_GCP_CAS_POOL_NAME}

map-mesh-gateway-ip-to-dns:
	@rm -f transaction.yaml
	@./gcp/map-dns-to-gateway.sh ${VEN_GCP_ZONE} ${VEN_DOMAIN_NAME}


## AWS Targets

# Create EKS Cluster
create-eks-cluster:
	@echo 'Creating EKS Cluster creation with ${VEN_AWS_PROFILE_NAME} in region ${VEN_AWS_REGION}'
	@./aws/aws-cluster.sh ${VEN_AWS_PROFILE_NAME} ${VEN_AWS_REGION} ${VEN_CLUSTER_NAME}

remove-eks-cluster:
ifeq ($(VEN_AWS_PROFILE_NAME),none)
	@eksctl delete cluster --region ${VEN_AWS_REGION} --name=${VEN_CLUSTER_NAME}
else
	@eksctl delete cluster --profile ${VEN_AWS_PROFILE_NAME} --region ${VEN_AWS_REGION} --name=${VEN_CLUSTER_NAME}
endif

create-aws-pca:
	@./aws/pca.sh ${AWS_PROFILE_NAME} ${REGION} ${K8S_CLUSTER_NAME} ${AWS_PCA_ARN}

remove-aws-pca:
	@echo "Nothing here"

