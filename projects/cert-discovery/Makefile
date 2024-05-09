MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean
SHELL := /bin/sh

########################################################################################################################
#  Review each command in the targets. 
########################################################################################################################

################### demo POC Scripts ################
 # Include personal settings
 include vars.sh

check-env:
ifndef VEN_CLOUD_API_KEY
	@(echo "VEN_CLOUD_API_KEY not defined. "; exit 1)
endif 

# Install venctl if the preferred mode of interacting with Venafi Control Plane is CLI. This will install
# venctl in /usr/local/bin . Tested on MacOS ARM
install-venctl:
	@curl -sSfL https://dl.venafi.cloud/venctl/latest/installer.sh | bash

init: _init 

_init: mkdirs create-vcp-service-account create-namespaces configure-namespace

mkdirs:
	@rm -rf artifacts
	@mkdir -p artifacts/venafi-install

create-namespaces:
	@kubectl apply -f namespaces/venafi.yaml

create-vcp-service-account: create-sa-for-discovery

####################### BEGIN - Targets to create Venafi Kubernetes Agent Service Account and secret ####################### 

create-sa-for-discovery:
	@echo "Service account for certificate discovery"
	@venctl iam service-accounts agent create \
		--name "${VEN_CLUSTER_NAME}" \
		--output-file "artifacts/venafi-install/venafi_agent_secret.json" \
		--output "secret" \
		--owning-team "${VEN_TEAM_NAME}" \
		--validity "${VEN_SVC_ACC_VALIDITY_DAYS}" \
		--api-key ${VEN_CLOUD_API_KEY}

create-discovery-secret: _transform_agent_secret_to_yaml
	@echo "Credentials for certificate discovery"
	@kubectl -n venafi apply -f artifacts/venafi-install/venafi_agent_secret.yaml || true

_transform_agent_secret_to_yaml:
	@jq -r '.private_key' artifacts/venafi-install/venafi_agent_secret.json > artifacts/venafi-install/venafi_agent_secret.yaml
	@jq -r '.client_id' artifacts/venafi-install/venafi_agent_secret.json > artifacts/venafi-install/venafi_agent_client_id.txt

####################### END  - Targets to create Venafi Kubernetes Agent Service Account and secret ####################### 

configure-namespace: create-discovery-secret

VEN_AGENT_SA_CLIENT_ID ?= $(shell cat artifacts/venafi-install/venafi_agent_client_id.txt)
install-agent:
	@helm upgrade venafi-kubernetes-agent oci://registry.venafi.cloud/charts/venafi-kubernetes-agent \
	--install \
	--namespace "venafi" \
	--set config.clientId="${VEN_AGENT_SA_CLIENT_ID}" \
	--set config.clusterName="${VEN_CLUSTER_NAME}" \
	--set config.clusterDescription="${VEN_CLUSTER_NAME}"

un-install:
	@@helm uninstall venafi-kubernetes-agent --namespace venafi  

remove-secrets:
	@kubectl -n venafi delete -f artifacts/venafi-install/venafi_agent_secret.yaml || true

clean: un-install remove-secrets
	@kubectl delete -f namespaces/venafi.yaml || true

#helper target to generate a public/private key pair for routing discoverd certs from VCP to TPP

generate-key-pair:
	@openssl ecparam -name secp521r1 -genkey -noout -out tlspc-to-dc-key.pem
	@openssl ec -in tlspc-to-dc-key.pem -pubout -out tlspc-to-dc-key.pub
	@echo @@@@@@@ The public key contents below should be used for service account in Venafi Control Plane @@@@@@@
	@cat tlspc-to-dc-key.pub
	@echo @@@@@@@ The public key contents above should be used for service account in Venafi Control Plane @@@@@@@
