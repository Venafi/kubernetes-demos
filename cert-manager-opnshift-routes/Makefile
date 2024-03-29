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
	@mkdir -p artifacts
create-namespaces:
	@kubectl apply -f namespaces/cert-manager.yaml


configure-namespace:
ifneq (${JS_AIRGAPPED},true)
	@echo "Creating docker registry secret. You must have the credentials file to create a secret"
	@echo
	@kubectl -n 'jetstack-secure' create secret docker-registry ${JS_DOCKER_REGISTRY_SECRET} \
			--docker-password="$$(cat ${JS_ENTERPRISE_CREDENTIALS_FILE})" \
			--docker-email='$(JS_DOCKER_EMAIL)' \
			--docker-server='${JS_CONTAINER_REGISTRY}' \
			--docker-username='_json_key' \
			--dry-run='client' \
			--save-config=true -o yaml | kubectl apply -f -
else
	@kubectl create secret docker-registry ${JS_DOCKER_REGISTRY_SECRET} --docker-server=${JS_DOCKER_REGISTRY_URL} --docker-username=${JS_DOCKER_REGISTRY_USERNAME} --docker-password=${JS_DOCKER_REGISTRY_PASSWORD} --docker-email=${JS_DOCKER_REGISTRY_EMAIL} -n cert-manager || true
endif 

install-cert-manager-openshift-route: init mkdirs create-namespaces configure-namespace
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/cert-manager-openshift-routes.yaml \
     > artifacts/cert-manager-openshift-routes.yaml
	@oc apply -f artifacts/cert-manager-openshift-routes.yaml -n cert-manager

remove-cert-manager-openshift-route:
	@oc delete -f artifacts/cert-manager-openshift-routes.yaml -n cert-manager || true