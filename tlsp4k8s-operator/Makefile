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
	@kubectl apply -f namespaces/sandbox.yaml

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

create-config-map-with-PEM-to-access-TPP:
	@cp ${JS_VENAFI_TPP_CA_BUNDLE_PEM_FILE} artifacts/venafi-server-ca.pem
	@kubectl create configmap venafi-tpp-ca-bundle --namespace='jetstack-secure' --from-file=ca.crt=artifacts/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

create-tlsp-creds:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/venafi-secret.yaml \
     > artifacts/venafi-secret.yaml	
	@kubectl apply -f artifacts/venafi-secret.yaml

create-tlsp-connection: 
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/install-tlsp-connection.yaml \
     > artifacts/install-tlsp-connection.yaml	
	
	@kubectl apply -f artifacts/install-tlsp-connection.yaml

create-certificate1:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/sample-cert1.yaml \
     > artifacts/sample-cert1.yaml
	@kubectl apply -f artifacts/sample-cert1.yaml

create-certificate2:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/sample-cert2.yaml \
     > artifacts/sample-cert2.yaml
	@kubectl apply -f artifacts/sample-cert2.yaml

remove-certificates:
	@kubectl delete -f artifacts/sample-cert1.yaml || true
	@kubectl delete -f artifacts/sample-cert2.yaml || true

remove-tlsp-connection:
	@kubectl delete -f artifacts/install-tlsp-connection.yaml

remove-tlsp-creds:
	@kubectl delete -f artifacts/venafi-secret.yaml

remove-config-map-with-PEM-to-access-TPP:
	@kubectl delete configmap venafi-tpp-ca-bundle --namespace='jetstack-secure'

remove-operator-cluster-addons:
	@kubectl delete -f artifacts/install-cluster-addons.yaml || true
	
remove-js-operator:
	@helm uninstall -n jetstack-secure js-operator || true
	@kubectl delete -f namespaces/jetstack-secure.yaml || true


clean: remove-certificates remove-operator-cluster-addons remove-tlsp-creds remove-config-map-with-PEM-to-access-TPP remove-js-operator
	@kubectl delete secret venafi-jetstack-enterprise-key -n jetstack-secure || true
	@kubectl delete -f namespaces/jetstack-secure.yaml || true