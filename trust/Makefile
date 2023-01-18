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

init: mkdirs create-namespaces configure-namespace _create-policy-and-rbac

mkdirs:
	@rm -rf artifacts
	@mkdir -p artifacts/trust
	@mkdir -p artifacts/trust/bundles

create-namespaces:
	@kubectl apply -f namespaces/jetstack-secure.yaml

configure-namespace:
ifneq (${JS_AIRGAPPED},true)
	@echo "Creating docker registry secret. You must have the credentials file to create a secret"
	@echo
	@kubectl -n 'jetstack-secure' create secret docker-registry ${JS_DOCKER_REGISTRY_SECRET} \
			--docker-password="$$(cat ${JS_ENTERPRISE_CREDENTIALS_FILE})" \
			--docker-email='$(JS_DOCKER_REGISTRY_EMAIL)' \
			--docker-server='${JS_CONTAINER_REGISTRY_URL}' \
			--docker-username='_json_key' \
			--dry-run='client' \
			--save-config=true -o yaml | kubectl apply -f -
else
	@kubectl create secret docker-registry ${JS_DOCKER_REGISTRY_SECRET} --docker-server=${JS_DOCKER_REGISTRY_URL} --docker-username=${JS_DOCKER_REGISTRY_USERNAME} --docker-password=${JS_DOCKER_REGISTRY_PASSWORD} --docker-email=${JS_DOCKER_REGISTRY_EMAIL} || true
endif 


_create-policy-and-rbac:
	@kubectl apply -f config/cert-policy.yaml


_helm_init:
	@echo 'Setting up helm with the correct repos'
	@helm repo update
	
install-cert-manager-trust: _helm_init
	@echo 'Installing Jetstack cert-manager trust operator.....'
	@cp templates/values.yaml artifacts/trust/values.yaml 
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/values.yaml \
     > artifacts/trust/values.yaml

	@helm upgrade \
		--install -f artifacts/trust/values.yaml trust-manager \
		--namespace jetstack-secure \
		oci://${JS_CONTAINER_REGISTRY}/charts/trust-manager \
	    --version ${JS_CERT_MANAGER_TRUST_VERSION} \
		--wait

_remove-policy-and-rbac:
	@kubectl delete -f config/cert-policy.yaml || true

remove-cert-manager-trust:
	@helm uninstall -n jetstack-secure trust-manager || true

clean: _remove-policy-and-rbac remove-cert-manager-trust


foo:
	@kubectl apply -f config/cert-policy-rbac.yaml
	@kubectl apply -f config/cert-policy.yaml
	@kubectl apply -f config/tmp.yaml 

bar:
	@kubectl delete -f config/cert-policy-rbac.yaml
	@kubectl delete -f config/cert-policy.yaml
	@kubectl delete -f config/tmp.yaml 