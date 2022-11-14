MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean
SHELL := /bin/sh

 # Include personal settings
 include ../settings.sh


########################################################################################################################
#  Review each command in the targets. 


########################################################################################################################

init: create-namespaces configure-namespace

create-namespaces:
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

_helm_init:
	@echo 'Setting up helm with the correct repos'
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo update
	@echo 'Installing Jetstack cert-manager.....'

install-cert-manager: _helm_init
	@helm upgrade \
		--install -f cert-manager/approver-enabled.yaml cert-manager \
		--namespace jetstack-secure \
		oci://eu.gcr.io/jetstack-secure-enterprise/charts/cert-manager \
	    --version ${JS_CERT_MANAGER_VERSION} \
		--wait

install-cert-manager-without-auto-approver: _helm_init
	@helm upgrade \
		--install -f cert-manager/approver-disabled.yaml cert-manager \
		--namespace jetstack-secure \
		oci://eu.gcr.io/jetstack-secure-enterprise/charts/cert-manager \
	    --version ${JS_CERT_MANAGER_VERSION} \
		--wait

create-cert:
	@kubectl apply -f cert-manager/sample-cert.yaml

remove-cert:
	@kubectl delete -f cert-manager/sample-cert.yaml || true

remove-cert-manager:
	@helm uninstall -n jetstack-secure cert-manager || true
	@kubectl delete -f namespaces/jetstack-secure.yaml || true

renew-cert:
	@cmctl -n sandbox renew test-cert
	@cmctl -n sandbox status certificate test-cert
	@cmctl -n sandbox inspect secret test-cert

install: create-namespace configure-namespace install-cert-manager

clean: remove-cert remove-cert-manager
	@kubectl delete secret venafi-jetstack-enterprise-key -n jetstack-secure || true
	@kubectl delete -f namespaces/jetstack-secure.yaml || true