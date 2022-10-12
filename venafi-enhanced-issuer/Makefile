MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean
SHELL := /bin/sh

 # Include personal settings
 include ../settings.sh

check-env:
ifndef JS_VENAFI_TPP_URL
	@(echo "JS_VENAFI_TPP_URL not defined. "; exit 1)
endif 

mkdirs:
	@rm -rf artifacts
	@mkdir -p artifacts/venafi-enhanced
	@mkdir -p artifacts/venafi-enhanced/config


################## PREP KUBERNETES CLUSTER FOR ISOLATED ISSUER #################
init: mkdirs create-namespaces configure-namespace

create-namespaces:
	@kubectl apply -f namespaces/jetstack-secure.yaml
	@kubectl apply -f namespaces/sandbox.yaml

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

install-jetstack-venafi-enhanced-issuer-module: 
	@echo 'Setting up helm with the correct repos'
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo add jetstack-secure-enterprise gs://jetstack-secure-enterprise-charts --force-update
	@helm repo update
	@echo 'Installing Venafi Jetstack Venafi Enhanced Issuer Module.....'
	
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/values.yaml \
     > artifacts/venafi-enhanced/config/values.yaml

	@helm upgrade \
		--install -f artifacts/venafi-enhanced/config/values.yaml js \
		--namespace jetstack-secure \
		oci://eu.gcr.io/jetstack-secure-enterprise/charts/venafi-enhanced-issuer \
	    --version ${JS_VENAFI_ENHANCED_ISSUER_VERSION} \
		--wait

_create-config-map-with-PEM-to-access-TPP:
	@cp ${JS_VENAFI_TPP_CA_BUNDLE_PEM_FILE} artifacts/venafi-enhanced/config/venafi-server-ca.pem
	@kubectl create configmap venafi-tpp-ca-bundle --namespace='jetstack-secure' --from-file=ca.crt=artifacts/venafi-enhanced/config/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

create-venafi-issuer: _create-config-map-with-PEM-to-access-TPP
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/venafi-issuer.yaml \
     > artifacts/venafi-enhanced/config/venafi-issuer.yaml
	@kubectl apply -f artifacts/venafi-enhanced/config/venafi-issuer.yaml

remove-venafi-issuer:
	@kubectl delete -f artifacts/venafi-enhanced/config/venafi-issuer.yaml || true

remove-jetstack-venafi-enhanced-issuer-module:
	@echo 'Uninstalling Venafi Enhanced Issuer Module.....'
	@helm uninstall -n jetstack-secure js || true

clean: remove-venafi-issuer remove-jetstack-venafi-enhanced-issuer-module
	@kubectl delete secret vtpp-access-token -n jetstack-secure || true
	@kubectl delete configmap venafi-tpp-ca-bundle -n jetstack-secure || true
	

