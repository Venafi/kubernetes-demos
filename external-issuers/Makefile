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

init: mkdirs create-namespaces configure-namespace

mkdirs:
	@rm -rf artifacts
	@mkdir -p artifacts/kms
	@mkdir -p artifacts/kms/keys

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

_helm_init:
	@echo 'Setting up helm with the correct repos'
	@helm repo add kms-issuer 'https://skyscanner.github.io/kms-issuer'
	@helm repo update

install-kms-issuer: _helm_init
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < kms/templates/values.yaml \
     > artifacts/kms/values.yaml
	@helm upgrade \
	    --install -f artifacts/kms/values.yaml kms-issuer kms-issuer/kms-issuer \
  		--namespace jetstack-secure

#step 1
create-kmskey:
	@kubectl apply -f kms/config/kmskey.yaml

remove-kmskey:
	@kubectl delete -f kms/config/kmskey.yaml || true

#step 2
create-kms-issuer:
	@kubectl apply -f kms/config/kms-issuer.yaml

#step 3
validate-kms-issuer-ca:
	@kubectl -n sandbox get kmsissuer kms-issuer -o json | jq -r ".status.certificate" |  base64 --decode  | openssl x509 -noout -text

#step 4
create-policy-and-rbac:
	@kubectl apply -f kms/config/cert-policy-rbac.yaml
	@kubectl apply -f kms/config/cert-policy.yaml

#step 5
create-certs:
	@kubectl apply -f kms/config/sample-certs.yaml

remove-kms-issuer:
	@kubectl delete -f kms/config/kms-issuer.yaml || true

remove-kms-issuer-module:
	@helm uninstall -n jetstack-secure kms-issuer || true

remove-certs:
	@kubectl delete -f kms/config/sample-certs.yaml || true

remove-policy-and-rbac:
	@kubectl delete -f kms/config/cert-policy.yaml || true
	@kubectl delete -f kms/config/cert-policy-rbac.yaml || true
	
#step 6
clean-kms: remove-certs remove-kms-issuer remove-kmskey remove-policy-and-rbac remove-kms-issuer-module