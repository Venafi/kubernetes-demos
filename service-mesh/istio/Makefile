MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean 
SHELL := /bin/sh

DEFAULT_ISSUER_GROUP =cert-manager.io
DEFAULT_ISSUER_KIND =Issuer
CAS_ISSUER_GROUP =cas-issuer.jetstack.io
CAS_ISSUER_KIND =GoogleCASIssuer
PCA_ISSUER_GROUP =awspca.cert-manager.io
PCA_ISSUER_KIND =AWSPCAIssuer
PEM_FILE_PATH=\/var\/cert-manager\/ca.pem

 # Include personal settings
 include ../../settings.sh


########################################################################################################################
#  Review each command in the targets. 


########################################################################################################################

init: mkdirs create-namespaces configure-namespace

mkdirs:
	@rm -rf artifacts/istio-csr
	@mkdir -p artifacts/istio-csr
	@mkdir -p artifacts/istio-csr/vtpp
	@mkdir -p artifacts/istio-csr/vaas
	@mkdir -p artifacts/istio-csr/vault
	@mkdir -p artifacts/istio-csr/google-cas
	@mkdir -p artifacts/istio-csr/awspca
	
create-namespaces:
	@kubectl apply -f namespaces/istio-system.yaml
	@kubectl apply -f namespaces/mesh-apps.yaml
	@kubectl apply -f namespaces/jetstack-secure.yaml
	
configure-namespace:
	@echo "Creating docker registry secret. You must have the credentials file to create a secret"
	@echo
	@kubectl -n 'jetstack-secure' create secret docker-registry venafi-jetstack-enterprise-key \
		--docker-password="$$(cat ${JS_ENTERPRISE_CREDENTIALS_FILE})" \
		--docker-email='$(JS_DOCKER_EMAIL)' \
		--docker-server='eu.gcr.io' \
		--docker-username='_json_key' \
		--dry-run='client' \
		--save-config=true -o yaml | kubectl apply -f -

install-jetstack-istio-csr:
	@echo 'Setting up helm with the correct repos'
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo update
	@echo 'Installing Jetstack ISTIO CSR Agent.....'

	@helm upgrade \
	    --install -f artifacts/istio-csr/values.yaml cert-manager-istio-csr jetstack/cert-manager-istio-csr \
  		--namespace jetstack-secure \
  		--version ${JS_CERT_MANAGER_ISTIO_CSR_VERSION}

#### Venafi TPP Specific Targets #######
vtpp-step0: JS_CERT_MANAGER_ISSUER_GROUP=$(DEFAULT_ISSUER_GROUP)
vtpp-step0: JS_CERT_MANAGER_ISSUER_KIND = $(DEFAULT_ISSUER_KIND)
vtpp-step0: JS_ISTIO_CSR_PEM_ENCODED_ROOT = \#${PEM_FILE_PATH}
vtpp-step0: print_str=Venafi TPP
vtpp-step0: configure-istio-csr-template

vtpp-step1: _create-vtpp-ica-issuer _create-vtpp-intermediate-cert create-policy
vtpp-step2: _create_vtpp_root_ca-cert install-jetstack-istio-csr
vtpp-step3: _install-and-configure-istio
vtpp-step4: _create-peer-authentication
vtpp-step5: _create-vtpp-public-cert-issuer _create-vtpp-public-certificate
vtpp-step6: _create_entry_in_GCP_CloudDNS
vtpp-step7: _install-sample-app _create_gateway_resources_with_vtpp
vtpp-step8: _install-istio-tools #Optional - if you want Kiali , Grafana and Prometheus

_create-vtpp-ica-issuer:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vtpp/ica-issuer.yaml \
     > artifacts/istio-csr/vtpp/ica-issuer.yaml
	@kubectl apply -f artifacts/istio-csr/vtpp/ica-issuer.yaml

_create-vtpp-intermediate-cert: 
	@kubectl apply -f templates/vtpp/intermediate-cert.yaml

_create_vtpp_root_ca-cert:
	@cp ${JS_VENAFI_INTERMEDIATE_CA_ROOT_PEM_FILE} artifacts/istio-csr/vtpp/venafi-ica-root-ca.pem
	@kubectl create secret generic root-cert --namespace='jetstack-secure' --from-file=ca.pem=artifacts/istio-csr/vtpp/venafi-ica-root-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -
#Ideally this should be done as below
#kubectl get secret jetstack-istio-ca.istio-system.svc.cluster.local -n istio-system -o jsonpath="{.data.ca\.crt}" | base64 -d > artifacts/istio-csr/vtpp/venafi-ica-root-ca.pem
#And then create secret - instead of copying from file system and creating a secret.

_create-vtpp-public-cert-issuer:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vtpp/public-cert-issuer.yaml \
     > artifacts/istio-csr/vtpp/public-cert-issuer.yaml
	@kubectl apply -f artifacts/istio-csr/vtpp/public-cert-issuer.yaml

_create-vtpp-public-certificate:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vtpp/public-cert.yaml \
     > artifacts/istio-csr/vtpp/public-cert.yaml
	@kubectl apply -f artifacts/istio-csr/vtpp/public-cert.yaml

#### Venafi TPP Specific Targets #######

### Vault Specific targets to support Jetstack Istio-CSR
vault-step0: JS_CERT_MANAGER_ISSUER_GROUP=$(DEFAULT_ISSUER_GROUP)
vault-step0: JS_CERT_MANAGER_ISSUER_KIND = $(DEFAULT_ISSUER_KIND)
vault-step0: JS_ISTIO_CSR_PEM_ENCODED_ROOT = ${PEM_FILE_PATH}
vault-step0: print_str=Hashicorp Vault
vault-step0: configure-istio-csr-template

vault-step1:  _install_vault _create-vault-issuer create-policy
vault-step2: _create_vault_root_ca-cert install-jetstack-istio-csr
vault-step3: _install-and-configure-istio
vault-step4: _create-peer-authentication
vault-step5: _create-vaas-public-cert-issuer _create-vaas-public-certificate
vault-step6: _create_entry_in_GCP_CloudDNS
vault-step7: _install-sample-app _create_gateway_resources_with_vaas
vault-step8: _install-istio-tools #Optional - if you want Kiali , Grafana and Prometheus

_install_vault:
	@$(MAKE) -C ../../ install-vault-in-cluster --warn-undefined-variables

_create-vault-issuer:
	@echo 'Creating Vault Issuer as jetstack-istio-ca. All mesh workloads will be signed by Vault CA'
	@kubectl apply -f templates/vault/ica-issuer.yaml

_create_vault_root_ca-cert:
	@cp ../../scripts/vault/terraform/ca.pem artifacts/istio-csr/vault/vault-root-ca.pem
	@kubectl create secret generic root-cert --namespace='jetstack-secure' --from-file=ca.pem=artifacts/istio-csr/vault/vault-root-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

### Vault Specific targets to support Jetstack Istio-CSR

### Venafi as a Service specific targets to support Jetstack Istio-CSR
vaas-step0: JS_CERT_MANAGER_ISSUER_GROUP=$(DEFAULT_ISSUER_GROUP)
vaas-step0: JS_CERT_MANAGER_ISSUER_KIND = $(DEFAULT_ISSUER_KIND)
vaas-step0: print_str=Venafi TPP
vaas-step0: configure-istio-csr-template

vaas-step1: _create-vaas-ica-issuer _create-vaas-intermediate-cert
vaas-step2: install-jetstack-istio-csr
vaas-step3: _install-and-configure-istio
vaas-step4: _create-peer-authentication
vaas-step5: _create-vaas-public-cert-issuer _create-vaas-public-certificate
vaas-step6: _create_entry_in_GCP_CloudDNS
vaas-step7: _install-sample-app _create_gateway_resources_with_vaas
vaas-step8: _install-istio-tools #Optional - if you want Kiali , Grafana and Prometheus

_create-vaas-ica-issuer:
	@echo "Vaas ICA issuer"

_create-vaas-intermediate-cert:
	@echo "Vaas intermediate cert will be created by connecting to a VSatellite worker via VSatellite"

_create-vaas-public-cert-issuer:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vaas/public-cert-issuer.yaml \
     > artifacts/istio-csr/vaas/public-cert-issuer.yaml
	@kubectl apply -f artifacts/istio-csr/vaas/public-cert-issuer.yaml

_create-vaas-public-certificate:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vaas/public-cert.yaml \
     > artifacts/istio-csr/vaas/public-cert.yaml
	@kubectl apply -f artifacts/istio-csr/vaas/public-cert.yaml

### Venafi as a Service specific targets to support Jetstack Istio-CSR

### Google CAS Specific targets to support Jetstack Istio-CSR
google-cas-step0: JS_CERT_MANAGER_ISSUER_GROUP=$(CAS_ISSUER_GROUP)
google-cas-step0: JS_CERT_MANAGER_ISSUER_KIND = $(CAS_ISSUER_KIND)
google-cas-step0: print_str=Google CAS
google-cas-step0: configure-istio-csr-template

google-cas-step1: _install_google-cas-issuer _create-google-cas-issuer
google-cas-step2: install-jetstack-istio-csr
google-cas-step3: _install-and-configure-istio
google-cas-step4: _create-peer-authentication
google-cas-step5: _create-vaas-public-cert-issuer _create-vaas-public-certificate
google-cas-step6: _create_entry_in_GCP_CloudDNS
google-cas-step7: _install-sample-app _create_gateway_resources_with_vtpp
google-cas-step8: _install-istio-tools #Optional - if you want Kiali , Grafana and Prometheus
### Google CAS Specific targets to support Jetstack Istio-CSR


_create_entry_in_GCP_CloudDNS:
	@$(MAKE) -C ../../scripts map-mesh-gateway-ip-to-dns --warn-undefined-variables

_install-sample-app:
	@kubectl -n mesh-apps apply -f https://raw.githubusercontent.com/sitaramkm/microservices-demo/master/release/kubernetes-manifests.yaml

_install-and-configure-istio:
	@echo 'Installing Istio ${JS_ISTIO_VERSION}'
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/istio-operator.yaml \
     > artifacts/istio-csr/istio-operator.yaml
	@istioctl install -y -f artifacts/istio-csr/istio-operator.yaml

_create-peer-authentication:
	@echo 'Creating PeerAuthentication resource with mTLS=STRICT globally'
	@kubectl apply -f common/peerauthentication.yaml

_create_gateway_resources_with_vtpp: HOST_NAME=storefront-vtpp.${JS_JETSTACKER_DOMAIN_NAME}
_create_gateway_resources_with_vtpp: _create_gateway

_create_gateway_resources_with_vaas: HOST_NAME=storefront-vaas.${JS_JETSTACKER_DOMAIN_NAME}
_create_gateway_resources_with_vaas: _create_gateway

_create_gateway:
	@cat templates/istio-manifests.yaml | sed -e "s/REPLACE_WITH_HOST_NAME/${HOST_NAME}/g" > artifacts/istio-csr/istio-manifests.yaml
	@kubectl -n mesh-apps apply -f artifacts/istio-csr/istio-manifests.yaml
	@echo "####################################################################################################"
	@echo "######### Sample apps takes about 60 seconds before pods are Ready in mesh-apps namespace ##########"
	@echo "######### Access application using https://${HOSTNAME}                                    ##########"
	@echo "####################################################################################################"

_install-istio-tools:
	@echo 'Installing Kiali............'
	@kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${JS_ISTIO_SHORT_VERSION}/samples/addons/kiali.yaml
	@echo 'Installing Jaeger............'
	@kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${JS_ISTIO_SHORT_VERSION}/samples/addons/jaeger.yaml
	@echo 'Installing Prometheus............'
	@kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${JS_ISTIO_SHORT_VERSION}/samples/addons/prometheus.yaml
	@echo 'Installing Grafana............'
	@kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${JS_ISTIO_SHORT_VERSION}/samples/addons/grafana.yaml


awspca-step0: JS_CERT_MANAGER_ISSUER_GROUP=$(PCA_ISSUER_GROUP)
awspca-step0: JS_CERT_MANAGER_ISSUER_KIND = $(PCA_ISSUER_KIND)
awspca-step0: print_str=AWS PCA
awspca-step0: configure-istio-csr-template

configure-istio-csr-template:
	@echo "Setting Issuer Kind to ${JS_CERT_MANAGER_ISSUER_KIND}"
	@echo "Setting Issuer Group to ${JS_CERT_MANAGER_ISSUER_GROUP}"
	@echo "Setting CA PEM File path to ${JS_ISTIO_CSR_PEM_ENCODED_ROOT}" 
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/values.yaml \
     > artifacts/istio-csr/values1.yaml

	@cat artifacts/istio-csr/values1.yaml | sed -e "s/REPLACE_ISSUER_KIND/${JS_CERT_MANAGER_ISSUER_KIND}/g" > artifacts/istio-csr/values2.yaml
	@cat artifacts/istio-csr/values2.yaml | sed -e "s/REPLACE_ISSUER_GROUP/${JS_CERT_MANAGER_ISSUER_GROUP}/g" > artifacts/istio-csr/values3.yaml
	@cat artifacts/istio-csr/values3.yaml | sed -e "s/REPLACE_PATH_TO_PEM_FILE/${JS_ISTIO_CSR_PEM_ENCODED_ROOT}/g" > artifacts/istio-csr/values.yaml
	@echo "Setting up values for ${print_str} Istio CSR at artifacts/istio-csr/values.yaml"

_create-config-map-with-PEM-to-access-TPP:
	@cp ${JS_VENAFI_TPP_CA_BUNDLE_PEM_FILE} artifacts/istio-csr/vtpp/venafi-server-ca.pem
	@kubectl create configmap venafi-tpp-ca-bundle --namespace='jetstack-secure' --from-file=ca.crt=artifacts/istio-csr/vtpp/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

_create-tpp-access-secret-for-policy:
	@kubectl create secret generic access-token --namespace='jetstack-secure' --from-literal=access-token='${JS_VENAFI_TPP_ACCESS_TOKEN}' --dry-run=client --save-config=true -o yaml | kubectl apply -f -

create-policy: _create-config-map-with-PEM-to-access-TPP _create-tpp-access-secret-for-policy
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < common/cert-policy-and-rbac.yaml \
     > artifacts/istio-csr/cert-policy-and-rbac.yaml
	@echo "Applying policy to process certificate requests in istio-system"
	@kubectl apply -f artifacts/istio-csr/cert-policy-and-rbac.yaml

remove-policy:
	@echo "Removing policy to process certificate requests in istio-system"
	@kubectl delete -f artifacts/istio-csr/cert-policy-and-rbac.yaml

remove-cert-manager-istio-csr:
	@helm uninstall -n jetstack-secure cert-manager-istio-csr

cleanup: remove-cert-manager-istio-csr


# Replace mesh-ca requires doing a few specific tasks that potentially could cause some downtime 
# Step1 -> make init
# Step2 -> make vault-step0
# Step3 -> make vault-step1
# Step4 -> make replace-mesh-ca
# Step5 -> make restart-sample-app

replace-mesh-ca-prep: init vault-step0 vault-step1 vault-step2

replace-mesh-ca:
	@cmctl renew istiod -n istio-system
	@kubectl rollout restart deployment istiod -n istio-system 
	@kubectl rollout restart deployment istio-ingressgateway -n istio-system 
	@kubectl rollout restart deployment istio-egressgateway -n istio-system 

restart-sample-app:
	@kubectl -n mesh-apps rollout restart deployment adservice
	@kubectl -n mesh-apps rollout restart deployment cartservice
	@kubectl -n mesh-apps rollout restart deployment checkoutservice
	@kubectl -n mesh-apps rollout restart deployment currencyservice
	@kubectl -n mesh-apps rollout restart deployment emailservice
	@kubectl -n mesh-apps rollout restart deployment frontend
	@kubectl -n mesh-apps rollout restart deployment paymentservice
	@kubectl -n mesh-apps rollout restart deployment productcatalogservice
	@kubectl -n mesh-apps rollout restart deployment recommendationservice
	@kubectl -n mesh-apps rollout restart deployment redis-cart
	@kubectl -n mesh-apps rollout restart deployment shippingservice

getcr: SVID_NAME=spiffe://jetstack-dev/ns/mesh-apps/sa/storefrontdemo-recommendationservice
getcr:
	kubectl get certificaterequests.cert-manager.io \
		-n istio-system \
		-o jsonpath='{range .items[?(@.metadata.annotations.istio\.cert-manager\.io/identities=="${SVID_NAME}")]} \
		{ .metadata.namespace },{ .metadata.name}{"\n"}{end}'

validate-secret: NAMESPACE=mesh-apps
validate-secret: APP=frontend
validate-secret: PODNAME=$(kubectl get pods -n ${NAMESPACE} -o jsonpath='{.items..metadata.name}' --selector app=${APP}) 
validate-secret:
	@echo "Namespace ${NAMESPACE}"
	@echo "Application is ${APP}"
	@echo "Pod name is ${PODNAME}"

    #istioctl -n mesh-apps proxy-config secret paymentservice-864d9f4df5-w89z7  \
	-o json | \
	jq -r '.dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes' | \
	base64 --decode | \
	openssl x509 -text -noout
	
	