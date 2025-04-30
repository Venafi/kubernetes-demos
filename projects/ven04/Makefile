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

check-env:
ifndef CYBR_CLOUD_API_KEY
	@(echo "CYBR_CLOUD_API_KEY not defined. "; exit 1)
endif 

########################################################################################################################
#  Review each command in the targets. 

########################################################################################################################

#Suffix for auto generated resources
gen_timestamp:
	@echo $$(date +%S%H%M%d%m) > artifacts/resource-suffix.txt

RESOURCE_SUFFIX ?= $(shell cat artifacts/resource-suffix.txt)

_init: mkdirs gen_timestamp create-vcp-service-account create-namespaces configure-namespace

init-cloud: _init setup-cloud-config

mkdirs:
	@rm -rf artifacts
	@mkdir -p artifacts/cyberark-install
	@mkdir -p artifacts/config
	@mkdir -p artifacts/samples

# Install venctl if the preferred mode of interacting with Venafi Control Plane is CLI. This will install
# venctl in /usr/local/bin . Tested on MacOS ARM
install-venctl:
	@curl -sSfL https://dl.venafi.cloud/venctl/latest/installer.sh | bash

create-vcp-service-account: create-sa-for-discovery create-sa-for-registry

####################### BEGIN - Targets to create Venafi Kubernetes Agent Service Account and secret ####################### 
create-sa-for-discovery:
	@echo "Service account for certificate discovery"
	@venctl iam service-accounts agent create \
		--name "demo-agent-${RESOURCE_SUFFIX}" \
		--output-file "artifacts/cyberark-install/cybr_mis_agent_secret.json" \
		--output "secret" \
		--owning-team "${CYBR_TEAM_NAME}" \
		--validity 10 \
		--api-key ${CYBR_CLOUD_API_KEY}

create-discovery-secret: _transform_agent_secret_to_yaml
	@echo "Credentials for certificate discovery"
	@kubectl -n cyberark apply -f artifacts/cyberark-install/cybr_mis_agent_secret.yaml || true

_transform_agent_secret_to_yaml:
	@jq -r '.private_key' artifacts/cyberark-install/cybr_mis_agent_secret.json > artifacts/cyberark-install/cybr_mis_agent_secret.yaml
	@jq -r '.client_id' artifacts/cyberark-install/cybr_mis_agent_secret.json > artifacts/cyberark-install/cybr_mis_agent_client_id.txt

####################### END  - Targets to create Venafi Kubernetes Agent Service Account and secret ####################### 

####################### BEGIN - Targets to create Venafi Registry Service Account and secret ####################### 

create-sa-for-registry:
	@echo "Creating Service Account in Venafi Control Plane for registry secret"
	@venctl iam service-account registry create \
		--name "demo-secret-${RESOURCE_SUFFIX}" \
		--output-file "artifacts/cyberark-install/cybr_mis_registry_secret.json" \
		--output "secret" \
		--owning-team "${CYBR_TEAM_NAME}" \
		--validity 10 \
		--scopes enterprise-cert-manager,enterprise-approver-policy,enterprise-venafi-issuer \
		--api-key ${CYBR_CLOUD_API_KEY}

create-registry-secret: _transform_registry_secret_to_yaml
	@echo "Credentials for venafi registry"
	@kubectl -n cyberark apply -f artifacts/cyberark-install/cybr_mis_registry_secret.yaml || true

_transform_registry_secret_to_yaml:
	@jq -r '.image_pull_secret' artifacts/cyberark-install/cybr_mis_registry_secret.json > artifacts/cyberark-install/cybr_mis_registry_secret.yaml

####################### END - Targets to create Venafi Registry Service Account and secret ####################### 

create-namespaces:
	@kubectl apply -f namespaces/cyberark.yaml
	@kubectl apply -f namespaces/sandbox.yaml

configure-namespace: create-registry-secret create-discovery-secret

generate-venafi-manifests:
	@echo "Generating Venafi Helm manifests for installation"
	@venctl components kubernetes manifest generate \
		--namespace cyberark \
		--approver-policy-enterprise \
		--approver-policy-enterprise-version ${approver-policy-enterprise} \
		--cert-manager \
		--cert-manager-version ${cert-manager} \
		--venafi-connection \
		--venafi-connection-version ${venafi-connection} \
		--venafi-enhanced-issuer \
		--venafi-enhanced-issuer-version ${venafi-enhanced-issuer} \
		--venafi-enhanced-issuer-values-files vei-values.yaml \
 		--venafi-kubernetes-agent \
		--venafi-kubernetes-agent-version ${venafi-kubernetes-agent} \
		--venafi-kubernetes-agent-values-files venafi-agent.yaml \
		--image-pull-secret-names venafi-image-pull-secret  > artifacts/cyberark-install/venafi-manifests.yaml

CYBR_AGENT_SA_CLIENT_ID ?= $(shell cat artifacts/cyberark-install/cybr_mis_agent_client_id.txt)

install: 
	@VENAFI_KUBERNETES_AGENT_CLIENT_ID=${CYBR_AGENT_SA_CLIENT_ID} \
		venctl components kubernetes manifest tool sync --file artifacts/cyberark-install/venafi-manifests.yaml 

un-install:
	@VENAFI_KUBERNETES_AGENT_CLIENT_ID=${CYBR_AGENT_SA_CLIENT_ID} \
		venctl components kubernetes manifest tool destroy --file artifacts/cyberark-install/venafi-manifests.yaml 

################################### BEGIN Venafi Cloud Targets #####################################
setup-cloud-config: create-agent-config-for-cloud create-vei-config-for-cloud

create-vei-config-for-cloud:
	@cp templates/helm/cloud-vei-values.yaml artifacts/cyberark-install/vei-values.yaml 

create-agent-config-for-cloud:
	@cat templates/helm/venafi-agent.yaml | sed -e "s/REPLACE_WITH_CLUSTER_NAME/mis-demo-cluster-${RESOURCE_SUFFIX}/g" > artifacts/cyberark-install/venafi-agent.yaml

_create-rbac-for-connections:
	@kubectl apply -f templates/common/venafi-connection-rbac.yaml

create-certificate-policy:
	@kubectl apply -f templates/common/cert-policy-and-rbac.yaml

_create-venafi-cloud-access-secret: 
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/cloud/venafi-cloud-secret.yaml \
     > artifacts/config/venafi-cloud-secret.yaml
	@kubectl apply -f artifacts/config/venafi-cloud-secret.yaml

_create-venafi-cloud-connection-with-access-token:
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/cloud/venafi-cloud-connection.yaml \
     > artifacts/config/venafi-cloud-connection.yaml
	@kubectl apply -f artifacts/config/venafi-cloud-connection.yaml

create-venafi-cloud-privateca-cluster-issuer: _create-rbac-for-connections _create-venafi-cloud-access-secret _create-venafi-cloud-connection-with-access-token
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/cloud/venafi-cloud-privateca-cluster-issuer.yaml \
     > artifacts/config/venafi-cloud-privateca-cluster-issuer.yaml
	@kubectl apply -f artifacts/config/venafi-cloud-privateca-cluster-issuer.yaml

create-venafi-cloud-publicca-cluster-issuer: _create-rbac-for-connections _create-venafi-cloud-access-secret _create-venafi-cloud-connection-with-access-token
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/cloud/venafi-cloud-publicca-cluster-issuer.yaml \
     > artifacts/cyberark-install/venafi-cloud-publicca-cluster-issuer.yaml
	@kubectl apply -f artifacts/cyberark-install/venafi-cloud-publicca-cluster-issuer.yaml

create-issuers: create-venafi-cloud-privateca-cluster-issuer create-venafi-cloud-publicca-cluster-issuer


create-public-cert:
	@cat templates/certificates/sample-publicca-cert.yaml | sed -e "s/REPLACE_WITH_SUB_DOMAIN/${RESOURCE_SUFFIX}/g" \
	> artifacts/cyberark-install/sample-publicca-cert-tmp.yaml
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < artifacts/cyberark-install/sample-publicca-cert-tmp.yaml \
     > artifacts/cyberark-install/sample-publicca-cert.yaml
	@kubectl apply -f artifacts/cyberark-install/sample-publicca-cert.yaml

create-private-cert:
	@cat templates/certificates/sample-privateca-cert.yaml | sed -e "s/REPLACE_WITH_SUB_DOMAIN/${RESOURCE_SUFFIX}/g" \
	> artifacts/cyberark-install/sample-privateca-cert-tmp.yaml
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < artifacts/cyberark-install/sample-privateca-cert-tmp.yaml \
     > artifacts/cyberark-install/sample-privateca-cert.yaml
	@kubectl apply -f artifacts/cyberark-install/sample-privateca-cert.yaml

create-certs: create-private-cert create-public-cert

## cleanup tasks 

remove-policy:
	@kubectl delete -f templates/common/cert-policy-and-rbac.yaml || true

remove-issuer-resources: _remove-cloud-issuer-resources _remove-common-issuer-resources 

_remove-cloud-issuer-resources:
	@kubectl delete -f artifacts/config/venafi-cloud-privateca-cluster-issuer.yaml || true
	@kubectl delete -f artifacts/config/venafi-cloud-publicca-cluster-issuer.yaml || true
	@kubectl delete -f artifacts/config/venafi-cloud-connection.yaml	|| true
	@kubectl delete -f artifacts/config/venafi-cloud-secret.yaml || true
	
_remove-common-issuer-resources:
	@kubectl delete -f templates/common/venafi-connection-rbac.yaml || true

remove-certs:
	@kubectl delete -f artifacts/cyberark-install/sample-privateca-cert.yaml || true
	@kubectl delete -f artifacts/cyberark-install/sample-publicca-cert.yaml || true

remove-secrets:
	@kubectl -n cyberark delete -f artifacts/cyberark-install/cybr_mis_agent_secret.yaml || true
	@kubectl -n cyberark delete -f artifacts/cyberark-install/cybr_mis_registry_secret.yaml || true

clean: remove-certs remove-policy remove-issuer-resources un-install remove-secrets
	@kubectl delete -f namespaces/cyberark.yaml || true
	@kubectl delete -f namespaces/sandbox.yaml || true
	@kubectl delete clusterrole venafi-issuer-cluster-role || true
	@kubectl delete clusterrolebinding venafi-issuer-cluster-role-binding || true
	@kubectl get crds | grep 'cert-manager.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true
	@kubectl get crds | grep 'jetstack.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true

