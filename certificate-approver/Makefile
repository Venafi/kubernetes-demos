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
	@mkdir -p artifacts/cert-approver
	@mkdir -p artifacts/cert-approver/venafi
	@mkdir -p artifacts/cert-approver/test-certs

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

install-cert-manager-without-auto-approver:
	@$(MAKE) -C ../enterprise-cert-manager init --warn-undefined-variables
	@$(MAKE) -C ../enterprise-cert-manager install-cert-manager-without-auto-approver --warn-undefined-variables

#Temporary config map required at this time. It is empty
create-config-map:
	@kubectl create configmap -n jetstack-secure cert-manager-approver-policy-rego --from-literal=rego= || true

install-jetstack-approver-policy-module: create-config-map
	@echo 'Setting up helm with the correct repos'
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo add jetstack-secure-enterprise gs://jetstack-secure-enterprise-charts --force-update
	@helm repo update
	@echo 'Installing Venafi Jetstack Certificate Approver Policy Module.....'
	
	@helm upgrade \
		--install -f approver-policy/values.yaml cert-manager-approver-policy \
		--namespace jetstack-secure \
		oci://eu.gcr.io/jetstack-secure-enterprise/charts/approver-policy-enterprise \
	    --version ${JS_POLICY_APPROVER_VERSION}

create-venafi-issuer:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/venafi-issuer.yaml \
     > artifacts/cert-approver/venafi/venafi-issuer.yaml
	kubectl apply -f artifacts/cert-approver/venafi/venafi-issuer.yaml

create-certificate1:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/sample-cert1.yaml \
     > artifacts/cert-approver/venafi/sample-cert1.yaml
	kubectl apply -f artifacts/cert-approver/venafi/sample-cert1.yaml

_create-config-map-with-PEM-to-access-TPP:
	@cp ${JS_VENAFI_TPP_CA_BUNDLE_PEM_FILE} artifacts/cert-approver/venafi/venafi-server-ca.pem
	@kubectl create configmap venafi-tpp-ca-bundle --namespace='jetstack-secure' --from-file=ca.crt=artifacts/cert-approver/venafi/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

_create-tpp-access-secret-for-policy:
	@kubectl create secret generic access-token --namespace='jetstack-secure' --from-literal=access-token='${JS_VENAFI_TPP_ACCESS_TOKEN}' --dry-run=client --save-config=true -o yaml | kubectl apply -f -

create-venafi-tpp-certificate-policy: _create-config-map-with-PEM-to-access-TPP _create-tpp-access-secret-for-policy
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/cert-policy.yaml \
     > artifacts/cert-approver/venafi/cert-policy.yaml
	@kubectl apply -f artifacts/cert-approver/venafi/cert-policy.yaml
	@kubectl apply -f templates/cert-policy-rbac.yaml

create-certificate2:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/sample-cert2.yaml \
     > artifacts/cert-approver/venafi/sample-cert2.yaml
	@kubectl apply -f artifacts/cert-approver/venafi/sample-cert2.yaml

create-certificate3:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/sample-cert3.yaml \
     > artifacts/cert-approver/venafi/sample-cert3.yaml
	@kubectl apply -f artifacts/cert-approver/venafi/sample-cert3.yaml

remove-certificates:
	@kubectl apply -f artifacts/cert-approver/venafi/sample-cert1.yaml
	@kubectl apply -f artifacts/cert-approver/venafi/sample-cert2.yaml
	@kubectl apply -f artifacts/cert-approver/venafi/sample-cert3.yaml

remove-issuer:
	@kubectl delete -f artifacts/cert-approver/venafi/venafi-issuer.yaml

remove-rbac:
	@kubectl delete -f templates/cert-policy-rbac.yaml

remove-cert-policy:
	@kubectl delete -f artifacts/cert-approver/venafi/cert-policy.yaml

remove-jetstack-approver-policy-module:
	@echo 'Uninstalling Venafi Jetstack Certificate Approver Policy Module.....'
	@helm uninstall -n jetstack-secure cert-manager-approver-policy

remove-cert-manager:
	@echo 'Uninstalling Venafi Jetstack cert-manager.....'
	@helm uninstall -n jetstack-secure cert-manager

clean: remove-certificates remove-issuer remove-rbac remove-cert-policy remove-jetstack-approver-policy-module remove-cert-manager
	@kubectl delete secret access-token -n jetstack-secure
	@kubectl delete configmap venafi-tpp-ca-bundle -n jetstack-secure
	@kubectl delete secret venafi-jetstack-enterprise-key -n jetstack-secure
	@kubectl delete -f namespaces/sandbox.yaml

