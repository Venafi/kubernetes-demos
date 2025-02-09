MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean 
SHELL := /bin/sh

# Include personal settings
 include ../main/cloud-settings.sh

create-cluster: create-gke-cluster

## GCP Targets 
create-gke-cluster:
	@echo 'Creating GKE Cluster for ${CYBR_GCP_PROJECT_ID} in region ${CYBR_GCP_REGION}'
	@./gcp/gke-cluster.sh ${CYBR_GCP_PROJECT_ID} ${CYBR_GCP_REGION} ${CYBR_CLUSTER_NAME}

remove-gke-cluster:
	@gcloud container clusters delete ${CYBR_CLUSTER_NAME} --region ${CYBR_GCP_REGION}

create-google-cas:
	@./gcp/cas.sh ${CYBR_GCP_PROJECT_ID} ${CYBR_GCP_REGION} ${CYBR_DOMAIN_NAME} ${CYBR_GCP_CAS_NAME} ${CYBR_GCP_CAS_POOL_NAME} ${CYBR_GCP_CAS_POOL_TIER}

remove-google-cas:
	@./gcp/cas-delete.sh ${CYBR_GCP_PROJECT_ID} ${CYBR_GCP_REGION} ${CYBR_DOMAIN_NAME} ${CYBR_GCP_CAS_NAME} ${CYBR_GCP_CAS_POOL_NAME}

map-mesh-gateway-ip-to-dns:
	@rm -f transaction.yaml
	@./gcp/map-dns-to-gateway.sh ${CYBR_GCP_ZONE} ${CYBR_DOMAIN_NAME}


## AWS Targets

# Create EKS Cluster
create-eks-cluster:
	@echo 'Creating EKS Cluster creation with ${CYBR_AWS_PROFILE_NAME} in region ${CYBR_AWS_REGION}'
	@./aws/aws-cluster.sh ${CYBR_AWS_PROFILE_NAME} ${CYBR_AWS_REGION} ${CYBR_CLUSTER_NAME}

remove-eks-cluster:
ifeq ($(CYBR_AWS_PROFILE_NAME),none)
	@eksctl delete cluster --region ${CYBR_AWS_REGION} --name=${CYBR_CLUSTER_NAME}
else
	@eksctl delete cluster --profile ${CYBR_AWS_PROFILE_NAME} --region ${CYBR_AWS_REGION} --name=${CYBR_CLUSTER_NAME}
endif

create-aws-pca:
	@./aws/pca.sh ${AWS_PROFILE_NAME} ${REGION} ${K8S_CLUSTER_NAME} ${AWS_PCA_ARN}

remove-aws-pca:
	@echo "Nothing here"

