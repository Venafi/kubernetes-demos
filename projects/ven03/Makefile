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
ifndef VEN_CLOUD_API_KEY
	@(echo "VEN_CLOUD_API_KEY not defined. "; exit 1)
endif 

########################################################################################################################
#  Review each command in the targets. 

########################################################################################################################

# Install venctl if the preferred mode of interacting with Venafi Control Plane is CLI. This will install
# venctl in /usr/local/bin . Tested on MacOS ARM
install-venctl:
	@curl -sSfL https://dl.venafi.cloud/venctl/latest/installer.sh | bash

init-cloud: _init setup-cloud-config

_init: mkdirs create-namespaces configure-namespace

mkdirs:
	@rm -rf artifacts
	@mkdir -p artifacts/venafi-install
	@mkdir -p artifacts/config
	@mkdir -p artifacts/samples

create-namespaces:
	@kubectl apply -f namespaces/sandbox.yaml

configure-namespace: create-registry-secret create-discovery-secret create-firefly-secret

####################### BEGIN - Targets to create required Venafi Secrets ####################### 
create-discovery-secret: 
#	@echo "Credentials for certificate discovery"
#	@kubectl -n ${VEN_NAMESPACE} apply -f artifacts/venafi-install/venafi_agent_secret.yaml || true

create-registry-secret:
	@echo "Credentials for venafi registry"
	@kubectl -n ${VEN_NAMESPACE} apply -f ${VEN_REGISTRY_SECRET_YAML} || true

create-firefly-secret: 
	@echo "Credentials for Firefly"
	@kubectl create secret generic venafi-credentials --namespace='${VEN_NAMESPACE}' --from-file=svc-acct.key=${VEN_FIREFLY_PRIVATE_KEY} --dry-run=client --save-config=true -o yaml | kubectl apply -f -

####################### END - Targets to create required Venafi Secrets ####################### 


generate-venafi-manifests:
	@echo "Generating Venafi Helm manifests for installation"
	@venctl components kubernetes manifest generate \
		--namespace ${VEN_NAMESPACE} \
		--approver-policy-enterprise \
		--approver-policy-enterprise-version ${approver-policy-enterprise} \
		--csi-driver \
		--csi-driver-version ${cert-manager-csi-driver} \
		--accept-firefly-tos \
		--firefly \
		--firefly-version ${firefly} \
		--trust-manager \
		--trust-manager-version ${trust-manager} \
		--venafi-connection \
		--venafi-connection-version ${venafi-connection} \
		--venafi-enhanced-issuer \
		--venafi-enhanced-issuer-version ${venafi-enhanced-issuer} \
		--venafi-enhanced-issuer-values-files vei-values.yaml \
		--ignore-dependencies \
		--image-pull-secret-names venafi-image-pull-secret  > artifacts/venafi-install/venafi-manifests.yaml

cert-manager-install:
	@helm install \
		cert-manager jetstack/cert-manager \
		--namespace ${VEN_NAMESPACE} \
		--create-namespace \
		--version v1.14.5 \
		--set installCRDs=true

install:
	@FIREFLY_VENAFI_CLIENT_ID=${VEN_FIREFLY_SA_CLIENT_ID} \
		venctl components kubernetes manifest tool sync --skip-needs --file artifacts/venafi-install/venafi-manifests.yaml 

un-install:
	@FIREFLY_VENAFI_CLIENT_ID=${VEN_FIREFLY_SA_CLIENT_ID} \		
		venctl components kubernetes manifest tool destroy --file artifacts/venafi-install/venafi-manifests.yaml 

################################### BEGIN Venafi Cloud Targets #####################################
setup-cloud-config: create-vei-config-for-cloud

create-vei-config-for-cloud:
	@cp templates/helm/cloud-vei-values.yaml artifacts/venafi-install/vei-values.yaml 

_create-venafi-cloud-access-secret: 
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/cloud/venafi-cloud-secret.yaml \
     > artifacts/config/venafi-cloud-secret.yaml
	@kubectl apply -n ${VEN_NAMESPACE} -f artifacts/config/venafi-cloud-secret.yaml

_create-venafi-cloud-connection-with-access-token:
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/cloud/venafi-cloud-connection.yaml \
     > artifacts/config/venafi-cloud-connection.yaml
	@kubectl apply -n ${VEN_NAMESPACE} -f artifacts/config/venafi-cloud-connection.yaml

create-venafi-cloud-privateca-cluster-issuer: _create-rbac-for-connections _create-venafi-cloud-access-secret _create-venafi-cloud-connection-with-access-token
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/cloud/venafi-cloud-privateca-cluster-issuer.yaml \
     > artifacts/config/venafi-cloud-privateca-cluster-issuer.yaml
	@kubectl apply -f artifacts/config/venafi-cloud-privateca-cluster-issuer.yaml

################################### END Venafi Cloud Targets #####################################

####### BEGIN - COMMON TO DC AND CLOUD #######

_create-rbac-for-connections:
	@kubectl apply -f templates/common/venafi-connection-rbac.yaml

create-certificate-policy:
	@kubectl apply -f templates/common/cert-policy-and-rbac.yaml

####### END - COMMON TO DC AND CLOUD #######

################################## SAMPLES ##################################

create-sample-certs:
	@kubectl apply -f samples/sample-firefly-certificates.yaml
	@kubectl apply -f samples/sample-cert.yaml

################################## SAMPLES ##################################

remove-sample-certs:
	@kubectl delete -f samples/sample-firefly-certificates.yaml || true
	@kubectl -n sandbox delete secret cert-two-days-1.svc.cluster.local || true
	@kubectl -n sandbox delete secret cert-ten-days-1.svc.cluster.local || true
	@kubectl -n sandbox delete secret cert-hundred-days-1.svc.cluster.local || true
	@kubectl delete -f samples/sample-cert.yaml || true
	@kubectl -n sandbox delete secret sample-cert01.svc.cluster.local || true

remove-policy:
	@kubectl delete -f templates/cert-policy-and-rbac.yaml || true

remove-issuer-resources: _remove-cloud-issuer-resources _remove-common-issuer-resources 

_remove-cloud-issuer-resources:
	@kubectl delete -f artifacts/config/venafi-cloud-privateca-cluster-issuer.yaml || true
	@kubectl delete -n ${VEN_NAMESPACE} -f artifacts/config/venafi-cloud-connection.yaml	|| true
	@kubectl delete -n ${VEN_NAMESPACE} -f artifacts/config/venafi-cloud-secret.yaml || true
	
_remove-common-issuer-resources:
	@kubectl delete -f templates/common/venafi-connection-rbac.yaml || true

remove-secrets:
	@kubectl -n ${VEN_NAMESPACE} delete -f artifacts/venafi-install/venafi_agent_secret.yaml || true
	@kubectl -n ${VEN_NAMESPACE} delete -f artifacts/venafi-install/venafi_registry_secret.yaml || true

clean: remove-sample-certs remove-policy remove-issuer-resources un-install remove-secrets
	@kubectl delete -f namespaces/sandbox.yaml || true
	@kubectl delete clusterrole venafi-issuer-cluster-role || true
	@kubectl delete clusterrolebinding venafi-issuer-cluster-role-binding || true
#	@kubectl get crds | grep 'cert-manager.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true
	@kubectl get crds | grep 'jetstack.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true


#helper target to clean up unused Firefly intermediates
delete-firefly-intermediateCertificates:
	@echo "Delete Firefly intermediate certificate"
	@curl --location --request DELETE 'https://api.venafi.cloud/v1/distributedissuers/intermediatecertificates/e931c810-f36e-11ee-a89e-b3d87834cdaf' \
	--header 'tppl-api-key: ${VEN_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json'

#helper target to generate a public/private key pair for routing discoverd certs from VCP to TPP

generate-key-pair:
	@openssl ecparam -name secp521r1 -genkey -noout -out tlspc-to-dc-key.pem
	@openssl ec -in tlspc-to-dc-key.pem -pubout -out tlspc-to-dc-key.pub
	@echo @@@@@@@ The public key contents below should be used for service account in Venafi Control Plane @@@@@@@
	@cat tlspc-to-dc-key.pub
	@echo @@@@@@@ The public key contents above should be used for service account in Venafi Control Plane @@@@@@@

