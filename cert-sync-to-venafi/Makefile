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
	@mkdir -p artifacts/cert-sync
	@mkdir -p artifacts/cert-sync/venafi
	@mkdir -p artifacts/cert-sync/test-certs

################## PREP KUBERNETES CLUSTER FOR ISOLATED ISSUER #################
init: mkdirs make-namespaces configure-namespace

make-namespaces:
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
	@(echo "do nothing")
endif 


create-venafi-tpp-access-secret:
	@kubectl create secret generic access-token --namespace='jetstack-secure' --from-literal=access-token='${JS_VENAFI_TPP_ACCESS_TOKEN}' --dry-run=client --save-config=true -o yaml | kubectl apply -f -

install-certificate-sync-module: create-venafi-tpp-access-secret
	@echo 'Setting up helm with the correct repos'
	@helm repo update
	@echo 'Installing Venafi Jetstack Certificate Sync Module.....'
	
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < cert-sync/values.yaml \
     > artifacts/cert-sync/venafi/values.yaml

	@helm upgrade \
		--install -f artifacts/cert-sync/venafi/values.yaml cert-sync-to-venafi  \
		--namespace jetstack-secure \
		oci://${JS_CONTAINER_REGISTRY}/charts/cert-discovery-venafi \
		--version ${JS_VENAFI_CERT_SYNC_VERSION} \
        --set url=${JS_VENAFI_TPP_URL} --set zone=${JS_VENAFI_CERT_SYNC_POLICY_FOLDER}


create-tls-secrets: create-tls-secret1 create-tls-secret2

create-tls-secret1:
	@openssl req -x509 \
        -nodes -days 1 \
        -newkey rsa:2048 \
        -keyout artifacts/cert-sync/test-certs/tls1.key \
        -out artifacts/cert-sync/test-certs/tls1.crt \
        -subj "/C=GB/ST=London/L=London/O=My Org/OU=App Team-RSA2048/CN=foo2048.bar.com"
	
	@kubectl -n sandbox create secret tls sandbox-cert1 --key="artifacts/cert-sync/test-certs/tls1.key" --cert="artifacts/cert-sync/test-certs/tls1.crt"

create-tls-secret2:
	@openssl req -x509 \
			-sha1 -nodes \
			-days 90 \
			-newkey rsa:512 \
			-keyout artifacts/cert-sync/test-certs/tls2.key \
			-out artifacts/cert-sync/test-certs/tls2.crt -subj \
			"/C=GB/ST=London/L=London/O=My Org/OU=App Team-RSA512/CN=foo512.bar.com"

	@kubectl -n sandbox create secret tls sandbox-cert2 --key="artifacts/cert-sync/test-certs/tls2.key" --cert="artifacts/cert-sync/test-certs/tls2.crt"

remove-tls-secret2:
	@kubectl -n sandbox delete secret sandbox-cert2 || true

remove-tls-secret1:
	@kubectl -n sandbox delete secret sandbox-cert1 || true

remove-tls-secrets: remove-tls-secret1 remove-tls-secret2

install-configure: mkdirs create-namespaces configure-namespace create-venafi-tpp-access-secret install-certificate-sync-module

remove-certificate-sync-module: remove-tls-secrets
	@echo 'Uninstalling certificate sync module'
	@helm uninstall -n jetstack-secure cert-sync-to-venafi || true
