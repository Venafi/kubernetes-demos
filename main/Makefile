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
# Include optionally - use cloud-settings-template.sh to create cloud-setting.sh
-include cloud-settings.sh

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
init-dc: _init setup-datacenter-config

mkdirs:
	@rm -rf artifacts
	@mkdir -p artifacts/cyberark-install
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

####################### BEGIN - Targets to create Venafi Firefly Service Account and secret ####################### 

create-sa-for-firefly:
	@echo "Creating Service account in Venafi Control Plane for Firefly"
	@venctl iam service-accounts firefly create \
	--name "demo-firefly-${RESOURCE_SUFFIX}" \
	--output-file "artifacts/cyberark-install/cybr_mis_firefly_secret.json" \
	--output "secret" \
	--owning-team "${CYBR_TEAM_NAME}" \
	--validity 10 \
	--api-key ${CYBR_CLOUD_API_KEY}

create-firefly-secret: _transform_firefly_secret_to_yaml
	@echo "Credentials for Firefly"
	@kubectl -n cyberark apply -f artifacts/cyberark-install/cybr_mis_firefly_secret.yaml || true

_transform_firefly_secret_to_yaml:
	@echo "Credentials for Venafi Firefly"
	@jq -r '.private_key' artifacts/cyberark-install/cybr_mis_firefly_secret.json > artifacts/cyberark-install/cybr_mis_firefly_secret.yaml
	@jq -r '.client_id' artifacts/cyberark-install/cybr_mis_firefly_secret.json > artifacts/cyberark-install/cybr_mis_firefly_client_id.txt


####################### END - Targets to create Venafi Firefly Service Account and secret ####################### 

create-namespaces:
	@kubectl apply -f namespaces/cyberark.yaml
	@kubectl apply -f namespaces/sandbox.yaml

configure-namespace: create-registry-secret create-discovery-secret create-firefly-secret

generate-venafi-manifests:
	@echo "Generating Venafi Helm manifests for installation"
	@venctl components kubernetes manifest generate \
		--namespace cyberark \
		--approver-policy-enterprise \
		--approver-policy-enterprise-version ${approver-policy-enterprise} \
		--cert-manager \
		--cert-manager-version ${cert-manager} \
		--csi-driver \
		--csi-driver-version ${cert-manager-csi-driver} \
		--csi-driver-spiffe \
		--csi-driver-spiffe-version ${cert-manager-csi-driver-spiffe} \
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
		--image-pull-secret-names venafi-image-pull-secret  > artifacts/cyberark-install/venafi-manifests.yaml

CYBR_AGENT_SA_CLIENT_ID ?= $(shell cat artifacts/cyberark-install/cybr_mis_agent_client_id.txt)
CYBR_FIREFLY_SA_CLIENT_ID ?= $(shell cat artifacts/cyberark-install/cybr_mis_firefly_client_id.txt)

confirm:
	@while [ -z "$$CONFIRM" ]; do \
		read -r -p "Have you attached the Firefly service account to your config in the UI? [y/N] " CONFIRM; \
	done ; \
	if [ ! $$CONFIRM == "y" ]; then \
	if [ ! $$CONFIRM == "Y" ]; then \
		echo "######################################################################\n" \
		echo "The Firefly Config in the UI needs to be associated with the service\n" \
		echo "account name that maps to client id ${CYBR_FIREFLY_SA_CLIENT_ID}\n" \
		echo "######################################################################" ; exit 1 ; \
	fi \
	fi

install: confirm
	@VENAFI_KUBERNETES_AGENT_CLIENT_ID=${CYBR_AGENT_SA_CLIENT_ID} \
		FIREFLY_VENAFI_CLIENT_ID=${CYBR_FIREFLY_SA_CLIENT_ID} \
		CSI_DRIVER_SPIFFE_TRUST_DOMAIN=cluster.local \
		venctl components kubernetes manifest tool sync --file artifacts/cyberark-install/venafi-manifests.yaml 

un-install:
	@VENAFI_KUBERNETES_AGENT_CLIENT_ID=${CYBR_AGENT_SA_CLIENT_ID} \
		FIREFLY_VENAFI_CLIENT_ID=${CYBR_FIREFLY_SA_CLIENT_ID} \
		CSI_DRIVER_SPIFFE_TRUST_DOMAIN=cluster.local \
		venctl components kubernetes manifest tool destroy --file artifacts/cyberark-install/venafi-manifests.yaml 

generate-static-manifests:
	@echo "Generating static manifests if that's your preferred option"
	@VENAFI_KUBERNETES_AGENT_CLIENT_ID=${CYBR_AGENT_SA_CLIENT_ID} \
		FIREFLY_VENAFI_CLIENT_ID=${CYBR_FIREFLY_SA_CLIENT_ID} \
		CSI_DRIVER_SPIFFE_TRUST_DOMAIN=cluster.local \
		venctl components kubernetes manifest tool template --file artifacts/cyberark-install/venafi-manifests.yaml > artifacts/cyberark-install/kubernetes-manifests.yaml

################################### BEGIN Venafi Cloud Targets #####################################
setup-cloud-config: create-agent-config-for-cloud create-vei-config-for-cloud

create-vei-config-for-cloud:
	@cp templates/helm/cloud-vei-values.yaml artifacts/cyberark-install/vei-values.yaml 

create-agent-config-for-cloud:
	@cat templates/helm/venafi-agent.yaml | sed -e "s/REPLACE_WITH_CLUSTER_NAME/mis-demo-cluster-${RESOURCE_SUFFIX}/g" > artifacts/cyberark-install/venafi-agent.yaml

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

################################### END Venafi Cloud Targets #####################################

####### BEGIN - COMMON TO DC AND CLOUD #######

_create-rbac-for-connections:
	@kubectl apply -f templates/common/venafi-connection-rbac.yaml

create-certificate-policy:
	@kubectl apply -f templates/common/cert-policy-and-rbac.yaml

####### END - COMMON TO DC AND CLOUD #######

################################### BEGIN Venafi Data center Targets #####################################

get-venafi-token:
	@vcert getcred --username ${CYBR_USER_NAME} \
		           --password ${CYBR_USER_PASS} \
				   -u ${CYBR_SERVER_URL} \
				   --client-id ${CYBR_API_CLIENT} \
				   --scope "certificate:manage,revoke" \
				   --format json | tee /tmp/token

setup-datacenter-config: create-venafi-tpp-trust-anchor create-agent-config-for-dc create-vei-config-for-dc

create-vei-config-for-dc:
	@cp templates/helm/datacenter-vei-values.yaml artifacts/cyberark-install/vei-values.yaml 

create-agent-config-for-dc:
	@cat templates/helm/venafi-agent.yaml | sed -e "s/REPLACE_WITH_CLUSTER_NAME/mis-demo-cluster-${RESOURCE_SUFFIX}/g" > artifacts/cyberark-install/venafi-agent.yaml

create-venafi-tpp-trust-anchor:
	@cp ${CYBR_TPP_CA_BUNDLE_PEM_FILE} artifacts/config/venafi-server-ca.pem
	@kubectl create configmap venafi-tpp-ca-bundle --namespace='cyberark' --from-file=ca.crt=artifacts/config/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

_create-venafi-tpp-access-secret: 
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/dc/venafi-tpp-secret.yaml \
     > artifacts/config/venafi-tpp-secret.yaml
	@kubectl apply -f artifacts/config/venafi-tpp-secret.yaml

_create-venafi-tpp-connection-with-access-token:
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/dc/venafi-tpp-connection.yaml \
     > artifacts/config/venafi-tpp-connection.yaml
	@kubectl apply -f artifacts/config/venafi-tpp-connection.yaml

create-venafi-tpp-privateca-cluster-issuer: _create-rbac-for-connections _create-venafi-tpp-access-secret _create-venafi-tpp-connection-with-access-token
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/dc/venafi-tpp-privateca-cluster-issuer.yaml \
     > artifacts/config/venafi-tpp-privateca-cluster-issuer.yaml
	@kubectl apply -f artifacts/config/venafi-tpp-privateca-cluster-issuer.yaml


################################### END Venafi Data center Targets #####################################

################################## SAMPLES ##################################
#seed-data-tpp: CYBR_CLUSTER_ISSUER=venafi-tpp-privateca-cluster-issuer
#seed-data-tpp: _seed-data

#seed-data-cloud: CYBR_CLUSTER_ISSUER=venafi-cloud-privateca-cluster-issuer
#seed-data-cloud: _seed-data

seed-data: CYBR_CLUSTER_ISSUER=venafi-privateca-cluster-issuer
seed-data: _seed-data

_seed-data:
	@echo "Creating certificate resources with issuer as ${CYBR_CLUSTER_ISSUER}"
#Self signed cert
	@./samples/01.unmanaged-kid.sh
#Cert with long duration mounted on a pod
	@cat templates/certs/02-expiry-eddie-cert.yaml | sed -e "s/REPLACE_WITH_ISSUER_NAME/${CYBR_CLUSTER_ISSUER}/g" > artifacts/samples/02-expiry-eddie-cert.yaml
	@kubectl apply -f artifacts/samples/02-expiry-eddie-cert.yaml
	@./samples/02.expiry-eddie.sh
#Cert with bad key size
	@./samples/03.cipher-snake.sh
#Orphan cert
	@cat templates/certs/04-ghost-rider-cert.yaml | sed -e "s/REPLACE_WITH_ISSUER_NAME/${CYBR_CLUSTER_ISSUER}/g" > artifacts/samples/04-ghost-rider-cert.yaml
	@kubectl apply -f artifacts/samples/04-ghost-rider-cert.yaml
#phanton ca and cert
	@kubectl apply -f samples/cert-policy-and-rbac-self-signed.yaml 
	@kubectl apply -f samples/05-phantom-ca-cert.yaml
	@./samples/05.phantom-ca.sh

create-sample-firefly-certs:
	@kubectl apply -f samples/sample-firefly-certificates.yaml

check-sample-cert:
	@cmctl -n sandbox inspect secret expiry-eddie.svc.cluster.local

renew-sample-cert:	
	@cmctl -n sandbox renew expiry-eddie.svc.cluster.local

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
	@kubectl delete -f artifacts/config/venafi-tpp-privateca-cluster-issuer.yaml || true
	@kubectl delete -f artifacts/config/venafi-tpp-connection.yaml	|| true
	@kubectl delete -f artifacts/config/venafi-tpp-secret.yaml || true

_remove-cloud-issuer-resources:
	@kubectl delete -f artifacts/config/venafi-cloud-privateca-cluster-issuer.yaml || true
	@kubectl delete -f artifacts/config/venafi-cloud-connection.yaml	|| true
	@kubectl delete -f artifacts/config/venafi-cloud-secret.yaml || true
	
_remove-common-issuer-resources:
	@kubectl delete -f templates/common/venafi-connection-rbac.yaml || true

remove-secrets:
	@kubectl -n cyberark delete -f artifacts/cyberark-install/cybr_mis_agent_secret.yaml || true
	@kubectl -n cyberark delete -f artifacts/cyberark-install/cybr_mis_registry_secret.yaml || true

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
	@kubectl delete -f namespaces/cyberark.yaml || true
	@kubectl delete -f namespaces/sandbox.yaml || true
	@kubectl delete clusterrole venafi-issuer-cluster-role || true
	@kubectl delete clusterrolebinding venafi-issuer-cluster-role-binding || true
	@kubectl get crds | grep 'cert-manager.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true
	@kubectl get crds | grep 'jetstack.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true

### Additional targets for using Firefly to sign mesh workloads. 
mesh-setup:
	@kubectl apply -f namespaces/istio-system.yaml
	@kubectl apply -f namespaces/mesh-apps.yaml

mesh-step1: mesh-setup
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/helm/istio-csr-values.yaml \
     > artifacts/cyberark-install/istio-csr-values.yaml
	@kubectl apply -n istio-system -f templates/servicemesh/firefly-mesh-wi-issuer.yaml 

_create_sourceCA:
	@cp ${CYBR_TRUST_ANCHOR_ROOT_CA_PEM} artifacts/cyberark-install/cyberark-trust-anchor-root-ca.pem
	@kubectl create secret generic cyberark-trust-anchor --namespace='cyberark' --from-file=root-cert.pem=artifacts/cyberark-install/cyberark-trust-anchor-root-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

mesh-step2: _create_sourceCA
	@echo "Creating Firefly trust anchor"

	@kubectl create configmap istio-csr-ca --namespace='cyberark' \
		--from-literal=issuer-name=firefly-mesh-wi-issuer \
		--from-literal=issuer-kind=Issuer \
		--from-literal=issuer-group=firefly.venafi.com \
		--dry-run=client --save-config=true -o yaml | kubectl apply -f -

	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/servicemesh/firefly-trust-anchor.yaml \
     > artifacts/cyberark-install/firefly-trust-anchor.yaml
	@kubectl apply -n istio-system -f artifacts/cyberark-install/firefly-trust-anchor.yaml

mesh-step3:
	@echo "Generating Venafi Helm manifests for installing istio-csr. This assumes cert-manager is already installed."
	@venctl components kubernetes manifest generate \
		--namespace cyberark \
		--istio-csr \
		--istio-csr-version ${cert-manager-istio-csr} \
		--istio-csr-values-files istio-csr-values.yaml \
		--ignore-dependencies \
		--image-pull-secret-names venafi-image-pull-secret  > artifacts/cyberark-install/venafi-manifests-istio.yaml

	@ISTIO_TRUST_DOMAIN=cluster.local \
		venctl components kubernetes manifest tool sync --file artifacts/cyberark-install/venafi-manifests-istio.yaml 

mesh-step4: _install-and-configure-istio

_install-and-configure-istio:
	@cp templates/servicemesh/istio-config.yaml artifacts/cyberark-install/istio-config.yaml
	@istioctl install -y -f artifacts/cyberark-install/istio-config.yaml

mesh-step5: _create-peer-authentication
_create-peer-authentication:
	@cp templates/servicemesh/peerauthentication.yaml artifacts/cyberark-install/peerauthentication.yaml
	@kubectl apply -f artifacts/cyberark-install/peerauthentication.yaml

mesh-step6: _install-sample-app

mesh-step7-cloud: _create-tlspc-public-cert-issuer _create-tlspc-public-cert

_create-tlspc-public-cert-issuer:
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/cloud/venafi-cloud-publicca-cluster-issuer.yaml \
     > artifacts/cyberark-install/venafi-cloud-publicca-cluster-issuer.yaml
	@kubectl apply -f artifacts/cyberark-install/venafi-cloud-publicca-cluster-issuer.yaml
_create-tlspc-public-cert:
	@cat templates/cloud/venafi-cloud-managed-public-cert.yaml | sed -e "s/REPLACE_WITH_SUB_DOMAIN/${RESOURCE_SUFFIX}/g" \
	> artifacts/cyberark-install/venafi-cloud-managed-public-cert-tmp.yaml
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < artifacts/cyberark-install/venafi-cloud-managed-public-cert-tmp.yaml \
     > artifacts/cyberark-install/venafi-cloud-managed-public-cert.yaml
	@kubectl apply -f artifacts/cyberark-install/venafi-cloud-managed-public-cert.yaml

mesh-step7-tpp: _create-tpp-public-cert-issuer _create-tpp-public-cert
_create-tpp-public-cert-issuer:
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < templates/dc/venafi-tpp-publicca-cluster-issuer.yaml \
     > artifacts/cyberark-install/venafi-tpp-publicca-cluster-issuer.yaml
	@kubectl apply -f artifacts/cyberark-install/venafi-tpp-publicca-cluster-issuer.yaml
_create-tpp-public-cert:
	@cat templates/dc/venafi-tpp-managed-public-cert.yaml | sed -e "s/REPLACE_WITH_SUB_DOMAIN/${RESOURCE_SUFFIX}/g" \
	> artifacts/cyberark-install/venafi-tpp-managed-public-cert-tmp.yaml
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < artifacts/cyberark-install/venafi-tpp-managed-public-cert-tmp.yaml \
     > artifacts/cyberark-install/venafi-tpp-managed-public-cert.yaml
	@kubectl apply -f artifacts/cyberark-install/venafi-tpp-managed-public-cert.yaml

#mesh-step8: _create_entry_in_GCP_CloudDNS
mesh-step8: _create_entry_in_AWS_Route53
	
_create_entry_in_GCP_CloudDNS:
	@echo "Create DNS entry for ${RESOURCE_SUFFIX}.${CYBR_DOMAIN_FOR_SAMPLE_APP} to map to Gateway host/ip"
	@../scripts/gcp/map-dns-to-gateway.sh ${CYBR_GCP_ZONE} ${RESOURCE_SUFFIX}.${CYBR_DOMAIN_FOR_SAMPLE_APP}

_create_entry_in_AWS_Route53:
	@echo "Create DNS entry for ${RESOURCE_SUFFIX}.${CYBR_DOMAIN_FOR_SAMPLE_APP} to map to Gateway host/ip"
	@../scripts/aws/map-dns-to-gateway.sh ${CYBR_AWS_ZONE} ${RESOURCE_SUFFIX}.${CYBR_DOMAIN_FOR_SAMPLE_APP} ${CYBR_AWS_PROFILE_NAME}

mesh-step9:  _create_gateway_resources

#@kubectl -n mesh-apps apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/platform/kube/bookinfo.yaml
_install-sample-app:
	@kubectl -n mesh-apps apply -f https://raw.githubusercontent.com/sitaramkm/microservices-demo/refs/heads/main/release/kubernetes-manifests.yaml

_create_gateway_resources:
	@cat templates/servicemesh/sample-app-gateway.yaml | sed -e "s/REPLACE_WITH_SUB_DOMAIN/${RESOURCE_SUFFIX}/g" \
	> artifacts/samples/sample-app-gateway-tmp.yaml
	@envsubst "$$(printf '$${%s} ' $${!CYBR_*})" < artifacts/samples/sample-app-gateway-tmp.yaml \
     > artifacts/samples/sample-app-gateway.yaml
	@kubectl -n mesh-apps apply -f artifacts/samples/sample-app-gateway.yaml
	@echo "####################################################################################################"
	@echo "######### Sample apps takes about 60 seconds before pods are Ready in mesh-apps namespace ##########"
	@echo "######### Access application using https://${RESOURCE_SUFFIX}.${CYBR_DOMAIN_FOR_SAMPLE_APP}/     ###"
	@echo "####################################################################################################"

mesh-addons: _install-istio-addons

_install-istio-addons:
	@kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/release-1.24/samples/addons/kiali.yaml
	@kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/release-1.24/samples/addons/prometheus.yaml
	@kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/release-1.24/samples/addons/grafana.yaml

clean-mesh-setup:
	@kubectl -n mesh-apps delete -f artifacts/samples/sample-app-gateway.yaml || true
	@kubectl -n mesh-apps delete -f https://raw.githubusercontent.com/sitaramkm/microservices-demo/refs/heads/main/release/kubernetes-manifests.yaml || true
	@kubectl delete -f https://raw.githubusercontent.com/istio/istio/refs/heads/release-1.24/samples/addons/kiali.yaml || true
	@kubectl delete -f https://raw.githubusercontent.com/istio/istio/refs/heads/release-1.24/samples/addons/prometheus.yaml || true
	@kubectl delete -f https://raw.githubusercontent.com/istio/istio/refs/heads/release-1.24/samples/addons/grafana.yaml || true
	@kubectl delete -f artifacts/cyberark-install/venafi-tpp-managed-public-cert.yaml || true
	@kubectl delete -f artifacts/cyberark-install/venafi-tpp-publicca-cluster-issuer.yaml || true
	@kubectl delete -f artifacts/cyberark-install/venafi-cloud-managed-public-cert.yaml || true
	@kubectl delete -f artifacts/cyberark-install/venafi-cloud-publicca-cluster-issuer.yaml || true
	@kubectl delete -f artifacts/cyberark-install/peerauthentication.yaml || true
	@istioctl uninstall -y -f artifacts/cyberark-install/istio-config.yaml || true
	@ISTIO_TRUST_DOMAIN=cluster.local \
		venctl components kubernetes manifest tool destroy --file artifacts/cyberark-install/venafi-manifests-istio.yaml
	@kubectl -n istio-system delete -f templates/servicemesh/firefly-mesh-wi-issuer.yaml || true
	#more to delete here.
	@kubectl -n istio-system delete -f artifacts/cyberark-install/firefly-trust-anchor.yaml || true
	@kubectl delete secret cyberark-trust-anchor --namespace='cyberark' || true
	@kubectl delete -f namespaces/mesh-apps.yaml || true
	@kubectl delete -f namespaces/istio-system.yaml || true
	@kubectl delete clusterrole istiod-istio-system || true
	@kubectl delete clusterrole istio-reader-istio-system || true
	@kubectl delete clusterrolebinding istiod-istio-system || true
	@kubectl delete clusterrolebinding istio-reader-istio-system || true
	@kubectl get crds | grep 'istio.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true
	
print-svid: PODNAME=$$(kubectl get pods -n mesh-apps -o jsonpath='{.items..metadata.name}' --selector app=frontend ) 
print-svid:
	@echo "Pod name is ${PODNAME}"
	@istioctl -n mesh-apps proxy-config secret ${PODNAME} \
	-o json | \
	jq -r '.dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes' | \
	base64 --decode | \
	openssl x509 -text -noout


#helper target to clean up unused Firefly intermediates
delete-firefly-intermediateCertificates:
	@echo "Delete Firefly intermediate certificate"
	@curl --location --request DELETE 'https://api.venafi.cloud/v1/distributedissuers/intermediatecertificates/243dd310-29e0-11f0-9bb2-fd1d725dc567' \
	--header 'tppl-api-key: ${CYBR_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json'

#helper target to generate a public/private key pair for routing discoverd certs from VCP to TPP
generate-key-pair:
	@openssl ecparam -name secp521r1 -genkey -noout -out tlspc-to-dc-key.pem
	@openssl ec -in tlspc-to-dc-key.pem -pubout -out tlspc-to-dc-key.pub
	@echo @@@@@@@ The public key contents below should be used for service account in Venafi Control Plane @@@@@@@
	@cat tlspc-to-dc-key.pub
	@echo @@@@@@@ The public key contents above should be used for service account in Venafi Control Plane @@@@@@@

create-gcloud-cluster:
	@$(MAKE) -C ../scripts create-gke-cluster --warn-undefined-variables 

create-gcloud-cas:
	@$(MAKE) -C ../scripts create-google-cas --warn-undefined-variables

_remove-gcloud-cluster:
	@$(MAKE) -C ../scripts remove-gke-cluster --warn-undefined-variables

gcp-full-cleanup: _remove-gcloud-cluster
	@$(MAKE) -C ../scripts remove-google-cas --warn-undefined-variables

get-all-issuers:
	@kubectl get ClusterIssuer,Issuer,VenafiClusterIssuer,VenafiIssuer,issuers.firefly.venafi.com --all-namespaces -o custom-columns='Issuer_NAME:.metadata.name,Resource:.apiVersion,STATUS:.status.conditions[].type' 

get-all-policies:
	@kubectl get crp

get-all-secrets:
	#@kubectl get secrets -A -o json | jq '.items[] | select(.type=="kubernetes.io/tls") | .metadata.name'
	@kubectl get secrets --field-selector type=kubernetes.io/tls --all-namespaces -o=custom-columns='NAMESPACE:metadata.namespace','NAME:metadata.name'


install-eso:
	@helm repo add external-secrets https://charts.external-secrets.io

	@helm install external-secrets \
		  external-secrets/external-secrets \
		  -n external-secrets \
		  --create-namespace \
	      --set installCRDs=true

uninstall-eso:
	@helm uninstall --namespace external-secrets external-secrets