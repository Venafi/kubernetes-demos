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

update-openshift-venafi-scc:
	@oc create -f cert-manager/restricted-seccomp.yaml || true
	@oc adm policy add-scc-to-user jetstack-privileged -z default || true

create-namespaces:
	@kubectl apply -f namespaces/jetstack-secure.yaml


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
	@kubectl create secret docker-registry ${JS_DOCKER_REGISTRY_SECRET} --docker-server=${JS_DOCKER_REGISTRY_URL} --docker-username=${JS_DOCKER_REGISTRY_USERNAME} --docker-password=${JS_DOCKER_REGISTRY_PASSWORD} --docker-email=${JS_DOCKER_REGISTRY_EMAIL} -n jetstack-secure || true
endif 

install-js-operator:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/values.yaml \
     > artifacts/values.yaml

	@helm upgrade \
		--install -f artifacts/values.yaml js-operator \
		--namespace jetstack-secure \
		oci://${JS_CONTAINER_REGISTRY}/charts/js-operator \
	    --version ${JS_OPERATOR_VERSION} \
		--wait

operator-cluster-addons:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/install-cluster-addons.yaml \
     > artifacts/install-cluster-addons.yaml	
	
	@kubectl apply -f artifacts/install-cluster-addons.yaml

remove-operator-cluster-addons:
	@kubectl delete -f artifacts/install-cluster-addons.yaml || true
	
remove-js-operator:
	@helm uninstall -n jetstack-secure js-operator || true
	@kubectl delete -f namespaces/jetstack-secure.yaml || true

clean: remove-js-operator
	@kubectl delete secret venafi-jetstack-enterprise-key -n jetstack-secure || true
	@kubectl delete -f namespaces/jetstack-secure.yaml || true