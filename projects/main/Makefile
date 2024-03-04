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
gen_timestamp:
	@echo $$(date +%S%H%M%d%m) > artifacts/resource-suffix.txt

RESOURCE_SUFFIX ?= $(shell cat artifacts/resource-suffix.txt)

_init: mkdirs gen_timestamp create-vcp-service-account create-namespaces configure-namespace

init-cloud: _init setup-cloud-config
init-dc: _init setup-datacenter-config

mkdirs:
	@rm -rf artifacts
	@mkdir -p artifacts/venafi-install
	@mkdir -p artifacts/config
	@mkdir -p artifacts/samples

# Install venctl if the preferred mode of interacting with Venafi Control Plane is CLI. This will install
# venctl in /usr/local/bin . Tested on MacOS ARM
install-venctl:
	@curl -sSfL https://dl.venafi.cloud/venctl/latest/installer.sh | bash

create-vcp-service-account: create-sa-for-discovery create-sa-for-registry create-sa-for-firefly

####################### BEGIN - Targets to create Venafi Kubernetes Agent Service Account and secret ####################### 
create-sa-for-discovery:
	@echo "Service account for certificate discovery"
	@venctl iam service-accounts agent create \
		--name "demo-agent-${RESOURCE_SUFFIX}" \
		--credential-file "artifacts/venafi-install/venafi_agent_secret.json" \
		--credential-format "secret" \
		--owning-team "platform-admin" \
		--validity 3 \
		--api-key ${VEN_CLOUD_API_KEY}

create-discovery-secret: _transform_agent_secret_to_yaml
	@echo "Credentials for certificate discovery"
	@kubectl -n venafi apply -f artifacts/venafi-install/venafi_agent_secret.yaml || true

_transform_agent_secret_to_yaml:
	@jq -r '.private_key' artifacts/venafi-install/venafi_agent_secret.json > artifacts/venafi-install/venafi_agent_secret.yaml
	@jq -r '.client_id' artifacts/venafi-install/venafi_agent_secret.json > artifacts/venafi-install/venafi_agent_client_id.txt

####################### END  - Targets to create Venafi Kubernetes Agent Service Account and secret ####################### 

####################### BEGIN - Targets to create Venafi Registry Service Account and secret ####################### 

create-sa-for-registry:
	@echo "Creating Service Account in Venafi Control Plane for registry secret"
	@venctl iam service-account registry create \
		--name "demo-secret-${RESOURCE_SUFFIX}" \
		--credential-file "artifacts/venafi-install/venafi_registry_secret.json" \
		--credential-format "secret" \
		--owning-team "platform-admin" \
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
	@echo "Creating Service account in Venafi Control Plane for Firefly"
	@venctl iam service-accounts firefly create \
	--name "demo-firefly-${RESOURCE_SUFFIX}" \
	--credential-file "artifacts/venafi-install/venafi_firefly_secret.json" \
	--credential-format "secret" \
	--owning-team "platform-admin" \
	--validity 3 \
	--api-key ${VEN_CLOUD_API_KEY}

create-firefly-secret: _transform_firefly_secret_to_yaml
	@echo "Credentials for Firefly"
	@kubectl -n venafi apply -f artifacts/venafi-install/venafi_firefly_secret.yaml || true

_transform_firefly_secret_to_yaml:
	@echo "Credentials for Venafi Firefly"
	@jq -r '.private_key' artifacts/venafi-install/venafi_firefly_secret.json > artifacts/venafi-install/venafi_firefly_secret.yaml
	@jq -r '.client_id' artifacts/venafi-install/venafi_firefly_secret.json > artifacts/venafi-install/venafi_firefly_client_id.txt


####################### END - Targets to create Venafi Firefly Service Account and secret ####################### 

create-namespaces:
	@kubectl apply -f namespaces/venafi.yaml
	@kubectl apply -f namespaces/sandbox.yaml

configure-namespace: create-registry-secret create-discovery-secret create-firefly-secret

generate-venafi-manifests:
	@echo "Generating Venafi Helm manifests for installation"
	@venctl components kubernetes manifest generate \
		--namespace venafi \
		--approver-policy-enterprise \
		--approver-policy-enterprise-version ${approver-policy-enterprise} \
		--cert-manager \
		--cert-manager-version ${cert-manager} \
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
 		--venafi-kubernetes-agent \
		--venafi-kubernetes-agent-version ${venafi-kubernetes-agent} \
		--venafi-kubernetes-agent-values-files venafi-agent.yaml \
		--image-pull-secret-names venafi-image-pull-secret  > artifacts/venafi-install/venafi-manifests.yaml

VEN_AGENT_SA_CLIENT_ID ?= $(shell cat artifacts/venafi-install/venafi_agent_client_id.txt)
VEN_FIREFLY_SA_CLIENT_ID ?= $(shell cat artifacts/venafi-install/venafi_firefly_client_id.txt)

confirm:
	@while [ -z "$$CONFIRM" ]; do \
		read -r -p "Have you attached the Firefly service account to your config in the UI? [y/N] " CONFIRM; \
	done ; \
	if [ ! $$CONFIRM == "y" ]; then \
	if [ ! $$CONFIRM == "Y" ]; then \
		echo "######################################################################\n" \
		echo "The Firefly Config in the UI needs to be associated with the service\n" \
		echo "account name that maps to client id ${VEN_FIREFLY_SA_CLIENT_ID}\n" \
		echo "######################################################################" ; exit 1 ; \
	fi \
	fi

install: confirm
	@VENAFI_KUBERNETES_AGENT_CLIENT_ID=${VEN_AGENT_SA_CLIENT_ID} \
		FIREFLY_VENAFI_CLIENT_ID=${VEN_FIREFLY_SA_CLIENT_ID} \
		venctl components kubernetes manifest tool sync --file artifacts/venafi-install/venafi-manifests.yaml 

un-install:
	@VENAFI_KUBERNETES_AGENT_CLIENT_ID=${VEN_AGENT_SA_CLIENT_ID} \
		FIREFLY_VENAFI_CLIENT_ID=${VEN_FIREFLY_SA_CLIENT_ID} \
		venctl components kubernetes manifest tool destroy --file artifacts/venafi-install/venafi-manifests.yaml 

generate-static-manifests:
	@echo "Generating static manifests if that's your preferred option"
	@VENAFI_KUBERNETES_AGENT_CLIENT_ID=${VEN_AGENT_SA_CLIENT_ID} \
		FIREFLY_VENAFI_CLIENT_ID=${VEN_FIREFLY_SA_CLIENT_ID} \
		venctl components kubernetes manifest tool template --file artifacts/venafi-install/venafi-manifests.yaml > artifacts/venafi-install/kubernetes-manifests.yaml

################################### BEGIN Venafi Cloud Targets #####################################
setup-cloud-config: create-agent-config-for-cloud create-vei-config-for-cloud

create-vei-config-for-cloud:
	@cp templates/helm/cloud-vei-values.yaml artifacts/venafi-install/vei-values.yaml 

create-agent-config-for-cloud:
	@cat templates/helm/venafi-agent.yaml | sed -e "s/REPLACE_WITH_CLUSTER_NAME/demo-cluster-${RESOURCE_SUFFIX}/g" > artifacts/venafi-install/venafi-agent.yaml

_create-venafi-cloud-access-secret: 
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/cloud/venafi-cloud-secret.yaml \
     > artifacts/config/venafi-cloud-secret.yaml
	@kubectl apply -f artifacts/config/venafi-cloud-secret.yaml

_create-venafi-cloud-connection-with-access-token:
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/cloud/venafi-cloud-connection.yaml \
     > artifacts/config/venafi-cloud-connection.yaml
	@kubectl apply -f artifacts/config/venafi-cloud-connection.yaml

create-venafi-cloud-cluster-issuer: _create-rbac-for-connections _create-venafi-cloud-access-secret _create-venafi-cloud-connection-with-access-token
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/cloud/venafi-cloud-cluster-issuer.yaml \
     > artifacts/config/venafi-cloud-cluster-issuer.yaml
	@kubectl apply -f artifacts/config/venafi-cloud-cluster-issuer.yaml

################################### END Venafi Cloud Targets #####################################

####### BEGIN - COMMON TO DC AND CLOUD #######

_create-rbac-for-connections:
	@kubectl apply -f templates/common/venafi-connection-rbac.yaml

create-certificate-policy:
	@kubectl apply -f templates/common/cert-policy-and-rbac.yaml

####### END - COMMON TO DC AND CLOUD #######

################################### BEGIN Venafi Data center Targets #####################################

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
	@cat templates/helm/venafi-agent.yaml | sed -e "s/REPLACE_WITH_CLUSTER_NAME/demo-cluster-${RESOURCE_SUFFIX}/g" > artifacts/venafi-install/venafi-agent.yaml

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

create-venafi-tpp-cluster-issuer: _create-rbac-for-connections _create-venafi-tpp-access-secret _create-venafi-tpp-connection-with-access-token
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/dc/venafi-tpp-cluster-issuer.yaml \
     > artifacts/config/venafi-tpp-cluster-issuer.yaml
	@kubectl apply -f artifacts/config/venafi-tpp-cluster-issuer.yaml


################################### END Venafi Data center Targets #####################################

################################## SAMPLES ##################################
seed-data-tpp: VEN_CLUSTER_ISSUER=venafi-tpp-cluster-issuer
seed-data-tpp: _seed-data

seed-data-cloud: VEN_CLUSTER_ISSUER=venafi-cloud-cluster-issuer
seed-data-cloud: _seed-data

_seed-data:
	@echo "Creating certificate resources with issuer as ${VEN_CLUSTER_ISSUER}"
#Self signed cert
	@./samples/01.unmanaged-kid.sh
#Cert with long duration mounted on a pod
	@cat templates/certs/02-expiry-eddie-cert.yaml | sed -e "s/REPLACE_WITH_ISSUER_NAME/${VEN_CLUSTER_ISSUER}/g" > artifacts/samples/02-expiry-eddie-cert.yaml
	@kubectl apply -f artifacts/samples/02-expiry-eddie-cert.yaml
	@./samples/02.expiry-eddie.sh
#Cert with bad key size
	@./samples/03.cipher-snake.sh
#Orphan cert
	@cat templates/certs/04-ghost-rider-cert.yaml | sed -e "s/REPLACE_WITH_ISSUER_NAME/${VEN_CLUSTER_ISSUER}/g" > artifacts/samples/04-ghost-rider-cert.yaml
	@kubectl apply -f artifacts/samples/04-ghost-rider-cert.yaml
#phanton ca and cert
	@kubectl apply -f samples/cert-policy-and-rbac-self-signed.yaml 
	@kubectl apply -f samples/05-phantom-ca-cert.yaml
	@./samples/05.phantom-ca.sh

create-sample-firefly-certs:
	@kubectl apply -f samples/sample-firefly-certificates.yaml

check-sample-cert:
	@cmctl -n sandbox status certificate sample-cert01.svc.cluster.local
	@cmctl -n sandbox inspect secret sample-cert01.svc.cluster.local

renew-sample-cert:	
	@cmctl -n sandbox renew sample-cert01.svc.cluster.local

################################## SAMPLES ##################################

remove-sample-firefly-certs:
	@kubectl delete -f samples/sample-firefly-certificates.yaml || true
	@kubectl -n sandbox delete secret cert-two-days-1.svc.cluster.local || true
	@kubectl -n sandbox delete secret cert-ten-days-1.svc.cluster.local || true
	@kubectl -n sandbox delete secret cert-hundred-days-1.svc.cluster.local || true

remove-policy:
	@kubectl delete -f templates/cert-policy-and-rbac.yaml || true

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
	@kubectl -n venafi delete -f artifacts/venafi-install/venafi_agent_secret.yaml || true
	@kubectl -n venafi delete -f artifacts/venafi-install/venafi_registry_secret.yaml || true

remove-seed-data:

	@kubectl -n sandbox delete service phantom-ca-issued-nginx || true
	@kubectl -n sandbox delete deployment phantom-ca-issued-nginx || true
	@kubectl delete -f samples/05-phantom-ca-cert.yaml || true
	@kubectl -n sandbox delete secret phantom-ca-issued.svc.cluster.local || true
	@kubectl -n sandbox delete secret phantom-ca-key-pair || true
	@kubectl delete -f samples/cert-policy-and-rbac-self-signed.yaml || true

	@kubectl delete -f artifacts/samples/04-ghost-rider-cert.yaml || true
	@kubectl -n sandbox delete secret ghost-rider.svc.cluster.local || true

	@kubectl -n sandbox delete service cipher-snake-nginx || true
	@kubectl -n sandbox delete deployment cipher-snake-nginx || true
	@kubectl -n sandbox delete secret cipher-snake.svc.cluster.local || true
	
	@kubectl -n sandbox delete service expiry-eddie-nginx || true
	@kubectl -n sandbox delete deployment expiry-eddie-nginx || true
	@kubectl delete -f artifacts/samples/02-expiry-eddie-cert.yaml || true
	@kubectl -n sandbox delete secret expiry-eddie.svc.cluster.local || true
	
	@kubectl -n sandbox delete service unmanaged-kid-nginx || true
	@kubectl -n sandbox delete deployment unmanaged-kid-nginx || true
	@kubectl -n sandbox delete secret unmanaged-kid.svc.cluster.local || true

clean: remove-seed-data remove-sample-firefly-certs remove-policy remove-issuer-resources un-install remove-secrets
	@kubectl delete -f namespaces/venafi.yaml || true
	@kubectl delete -f namespaces/sandbox.yaml || true

### Additional targets for using Firefly to sign mesh workloads. 

mesh-setup:
	@kubectl apply -f namespaces/istio-system.yaml
	@kubectl apply -f namespaces/mesh-apps.yaml

mesh-step1: mesh-setup
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/helm/istio-csr-values.yaml \
     > artifacts/venafi-install/istio-csr-values.yaml
	@kubectl apply -n istio-system -f templates/servicemesh/venafi-firefly-issuer.yaml 

_create_sourceCA:
	@cp ${VEN_FIREFLY_ICA_ROOT_CA_PEM} artifacts/venafi-install/firefly-ica-root-ca.pem
	@kubectl create secret generic firefly-ica-root-cert --namespace='venafi' --from-file=ca.crt=artifacts/venafi-install/firefly-ica-root-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

mesh-step2: _create_sourceCA
	@echo "Creating Firefly trust anchor"
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/servicemesh/firefly-trust-anchor.yaml \
     > artifacts/venafi-install/firefly-trust-anchor.yaml
	@kubectl apply -n istio-system -f artifacts/venafi-install/firefly-trust-anchor.yaml

mesh-step3:
	@echo 'Installing Venafi istio CSR agent.....'
	@helm upgrade \
	    --install -f artifacts/venafi-install/istio-csr-values.yaml cert-manager-istio-csr \
  		--namespace venafi \
		oci://${VEN_CONTAINER_REGISTRY}/charts/cert-manager-istio-csr \
  		--version ${VEN_ISTIO_CSR_VERSION} \
		--wait

mesh-step4: _install-and-configure-istio

_install-and-configure-istio:
	@cp templates/servicemesh/istio-config.yaml artifacts/venafi-install/istio-config.yaml
	@istioctl install -y -f artifacts/venafi-install/istio-config.yaml

mesh-step5: _create-peer-authentication
_create-peer-authentication:
	@cp templates/servicemesh/peerauthentication.yaml artifacts/venafi-install/peerauthentication.yaml
	@kubectl apply -f artifacts/venafi-install/peerauthentication.yaml

mesh-step6: _create-tlspc-public-cert-issuer _create-tlspc-public-cert
_create-tlspc-public-cert-issuer:
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/tlspc/public-cert-issuer.yaml \
     > artifacts/firefly/tlspc-public-cert-issuer.yaml
	@kubectl apply -f artifacts/firefly/tlspc-public-cert-issuer.yaml
_create-tlspc-public-cert:
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/tlspc/public-cert.yaml \
     > artifacts/firefly/public-cert.yaml
	@kubectl apply -f artifacts/firefly/public-cert.yaml

mesh-step8: _install-sample-app _create_gateway_resources
#mesh-step8: _install-sample-app 
_install-sample-app:
	@kubectl -n mesh-apps apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/platform/kube/bookinfo.yaml

_create_gateway_resources: HOST_DNSNAME=storefront-vtlspc.${VEN_DOMAIN_NAME_FOR_SAMPLE_APP}
_create_gateway_resources: _create_gateway

_create_gateway:
	@cat templates/servicemesh/sample-app-gateway.yaml | sed -e "s/REPLACE_WITH_HOST_NAME/${HOST_DNSNAME}/g" > artifacts/samples/sample-app-gateway.yaml
	@kubectl -n mesh-apps apply -f artifacts/samples/sample-app-gateway.yaml
	@echo "####################################################################################################"
	@echo "######### Sample apps takes about 60 seconds before pods are Ready in mesh-apps namespace ##########"
	@echo "######### Access application using https://${HOST_DNSNAME}     ###"
	@echo "####################################################################################################"

clean-mesh-setup:
	@kubectl -n mesh-apps delete -f artifacts/samples/sample-app-gateway.yaml || true
	@kubectl -n mesh-apps delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/platform/kube/bookinfo.yaml
	@kubectl delete -f artifacts/venafi-install/peerauthentication.yaml || true
	@istioctl uninstall -y -f artifacts/venafi-install/istio-config.yaml || true
	@helm uninstall -n venafi cert-manager-istio-csr || true
	@kubectl -n istio-system delete -f templates/servicemesh/venafi-firefly-issuer.yaml || true
	#more to delete here.
	@kubectl -n istio-system delete -f artifacts/venafi-install/firefly-trust-anchor.yaml || true
	@kubectl delete secret firefly-ica-root-cert --namespace='venafi' || true
	@kubectl delete -f namespaces/mesh-apps.yaml || true
	@kubectl delete -f namespaces/istio-system.yaml || true


#helper target to clean up unused Firefly intermediates
delete-firefly-intermediateCertificates:
	@echo "Delete Firefly intermediate certificate"
	@curl --location --request DELETE 'https://api.venafi.cloud/v1/distributedissuers/intermediatecertificates/10f48000-500d-11ee-9992-05c5403141b5' \
	--header 'tppl-api-key: ${VEN_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json'
