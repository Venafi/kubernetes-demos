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
 # Include version settings
 include versions.sh


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
	@echo "Creating Service Account in Venafi Control Plane for registry secret"
	@venctl iam service-account registry create \
		--name "ven02-secret-${RESOURCE_SUFFIX}" \
		--credential-file "artifacts/venafi-install/venafi_registry_secret.json" \
		--credential-format "secret" \
		--owning-team "InfoSec" \
		--validity 3 \
		--scopes enterprise-cert-manager,enterprise-approver-policy,enterprise-venafi-issuer \
		--api-key ${VEN_CLOUD_API_KEY}

create-registry-secret: _transform_registry_secret_to_yaml
	@echo "Credentials for venafi registry"
	@kubectl -n venafi apply -f artifacts/venafi-install/venafi_registry_secret.yaml || true

_transform_registry_secret_to_yaml:
	@jq -r '.image_pull_secret' artifacts/venafi-install/venafi_registry_secret.json > artifacts/venafi-install/venafi_registry_secret.yaml

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
		--approver-policy-enterprise \
		--approver-policy-enterprise-version ${approver-policy-enterprise} \
		--cert-manager \
		--cert-manager-version ${cert-manager} \
		--trust-manager \
		--trust-manager-version ${trust-manager} \
		--venafi-connection \
		--venafi-connection-version ${venafi-connection} \
		--venafi-enhanced-issuer \
		--venafi-enhanced-issuer-version ${venafi-enhanced-issuer} \
		--venafi-enhanced-issuer-values-files vei-values.yaml \
		--image-pull-secret-names venafi-image-pull-secret  > artifacts/venafi-install/venafi-manifests.yaml

######## STEP 3 ##############
step3: install 

install:
	@venctl components kubernetes manifest tool sync --file artifacts/venafi-install/venafi-manifests.yaml 

un-install:
	@venctl components kubernetes manifest tool destroy --file artifacts/venafi-install/venafi-manifests.yaml || true

generate-static-manifests:
	@echo "Generating static manifests if that's your preferred option"
	@venctl components kubernetes manifest tool template --file artifacts/venafi-install/venafi-manifests.yaml > artifacts/venafi-install/kubernetes-manifests.yaml


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

#create-venafi-tpp-cluster-issuer: _create-venafi-tpp-trust-anchor _create-rbac-for-connections _create-venafi-tpp-access-secret _create-venafi-tpp-connection-with-access-token
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

setup-datacenter-config: _create-venafi-tpp-server-cert-secret create-agent-config-for-dc create-vei-config-for-dc

create-vei-config-for-dc:
	@cp templates/helm/datacenter-vei-values.yaml artifacts/venafi-install/vei-values.yaml 

create-agent-config-for-dc:
	@echo "skipping for this poc"

_create-venafi-tpp-server-cert-secret:
	@cp ${VEN_TPP_CA_BUNDLE_PEM_FILE} artifacts/venafi-install/venafi-server-ca.pem
	@kubectl create secret generic venafi-tpp-server-cert --namespace='venafi' --from-file=ca.crt=artifacts/venafi-install/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -
	@kubectl create configmap venafi-tpp-ca-bundle --namespace='venafi' --from-file=ca.crt=artifacts/venafi-install/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -	

_create-venafi-tpp-trust-anchor:
	@echo "Creating Venafi TPP server CA bundle"
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/dc/venafi-tpp-trust-bundle.yaml \
     > artifacts/venafi-install/venafi-tpp-trust-bundle.yaml
	@kubectl apply -n venafi -f artifacts/venafi-install/venafi-tpp-trust-bundle.yaml

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
	@kubectl -n venafi delete -f artifacts/venafi-install/venafi-tpp-trust-bundle.yaml || true

_remove-cloud-issuer-resources:
	@kubectl delete -f artifacts/config/venafi-cloud-cluster-issuer.yaml || true
	@kubectl delete -f artifacts/config/venafi-cloud-connection.yaml	|| true
	@kubectl delete -f artifacts/config/venafi-cloud-secret.yaml || true
	
_remove-common-issuer-resources:
	@kubectl delete -f templates/common/venafi-connection-rbac.yaml || true

remove-secrets:
	@kubectl -n venafi delete secret venafi-tpp-server-cert || true 

clean: remove-cert remove-policy remove-issuer-resources un-install remove-secrets
	@kubectl delete -f namespaces/venafi.yaml || true
	@kubectl delete -f namespaces/sandbox.yaml || true