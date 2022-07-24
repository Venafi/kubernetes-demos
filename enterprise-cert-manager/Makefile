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

create-namespace:
	@kubectl apply -f namespaces/cert-manager.yaml

configure-namespace:
	@echo "Creating docker registry secret. You must have the credentials file to create a secret"
	@echo
	@kubectl -n 'cert-manager' create secret docker-registry gcr-json-key \
		--docker-password="$$(cat ../sa-key.json)" \
		--docker-email='$(JS_DOCKER_EMAIL)' \
		--docker-server='eu.gcr.io' \
		--docker-username='_json_key' \
		--dry-run='client' \
		--save-config=true -o yaml | kubectl apply -f -

install-cert-manager:
	@echo 'Setting up helm with the correct repos'
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo update
	@echo 'Installing Jetstack cert-manager.....'

	@helm upgrade \
	    --install -f cert-manager/values.yaml cert-manager jetstack/cert-manager \
  		--namespace cert-manager \
  		--version ${JS_CERT_MANAGER_VERSION}

create-cert:
	@kubectl apply -f cert-manager/sample-cert.yaml

remove-cert:
	@kubectl delete -f cert-manager/sample-cert.yaml

remove-cert-manager:
	@helm uninstall -n cert-manager cert-manager
	@kubectl delete ns cert-manager

renew-cert:
	@cmctl -n sandbox renew test-cert
	@cmctl -n sandbox status certificate test-cert
	@cmctl -n sandbox inspect secret test-cert

install: create-namespace configure-namespace install-cert-manager

test: create-cert 

cleanup: remove-cert remove-cert-manager
