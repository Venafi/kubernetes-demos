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
	@mkdir -p artifacts/pod-identities
	@mkdir -p artifacts/csi-driver/venafi
	@mkdir -p artifacts/csi-driver/selfsigned

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

install-cert-manager:
	@$(MAKE) -C ../enterprise-cert-manager init --warn-undefined-variables
	@$(MAKE) -C ../enterprise-cert-manager install-cert-manager --warn-undefined-variables

install-cert-manager-csi-driver: 
	@echo 'Setting up helm with the correct repos'
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo update
	@echo 'Installing Jetstack cert-manager CSI Driver.....'

	@helm upgrade \
		--install -f csi-driver/values.yaml cert-manager-csi-driver jetstack/cert-manager-csi-driver \
		--namespace jetstack-secure \
		 --version ${JS_CERT_MANAGER_CSI_DRIVER_VERSION}

remove-cert-manager: remove-cert-manager-csi-driver
	@echo 'Uninstalling Jetstack Enterprise cert-manager'
	@helm uninstall -n jetstack-secure cert-manager

remove-cert-manager-csi-driver: 
	@echo 'Uninstalling Jetstack Enterprise cert-manager CSI Driver'
	@helm uninstall -n jetstack-secure cert-manager-csi-driver

create-policy-and-rbac:
	@cp templates/cert-policy-and-rbac-self-signed.yaml artifacts/csi-driver/selfsigned/cert-policy-and-rbac-self-signed.yaml
	@kubectl apply -f artifacts/csi-driver/selfsigned/cert-policy-and-rbac-self-signed.yaml

remove-policy-and-rbac:
	@kubectl delete -f artifacts/csi-driver/selfsigned/cert-policy-and-rbac-self-signed.yaml


create-sample-app:
	@kubectl apply -f https://raw.githubusercontent.com/cert-manager/csi-driver/main/deploy/example/example-app.yaml

remove-sample-app:
	@kubectl delete -f https://raw.githubusercontent.com/cert-manager/csi-driver/main/deploy/example/example-app.yaml

deploy-redis-server:

deploy-redis-client:
