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
prep-kubernetes: make-namespaces


create-namespaces:
	@kubectl apply -f namespaces/jetstack-secure.yaml
	@kubectl apply -f namespaces/sandbox.yaml

configure-namespace:
	@echo "Creating docker registry secret. You must have the credentials file to create a secret"
	@echo
	@kubectl -n 'jetstack-secure' create secret docker-registry venafi-jetstack-enterprise-key \
		--docker-password="$$(cat ../sa-key.json)" \
		--docker-email='$(JS_DOCKER_EMAIL)' \
		--docker-server='eu.gcr.io' \
		--docker-username='_json_key' \
		--dry-run='client' \
		--save-config=true -o yaml | kubectl apply -f -

create-venafi-tpp-access-secret:
	@kubectl create secret generic access-token --namespace='jetstack-secure' --from-literal=access-token='${JS_VENAFI_TPP_ACCESS_TOKEN}' --dry-run=client --save-config=true -o yaml | kubectl apply -f -

install-certificate-sync-module:
	@echo 'Setting up helm with the correct repos'
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo update
	@echo 'Installing Venafi Jetstack Certificate Sync Module.....'
	helm upgrade \
		--install -f cert-sync/values.yaml cert-sync-to-venafi  \
		--namespace jetstack-secure \
		oci://eu.gcr.io/jetstack-secure-enterprise/charts/cert-discovery-venafi \
        --set url=${JS_VENAFI_TPP_URL} --set zone=${JS_VENAFI_CERT_SYNC_POLICY_FOLDER}

remove-certificate-sync-module:
	@echo 'Uninstalling certificate sync module'
	@helm uninstall -n jetstack-secure cert-sync-to-venafi


create-tls-secrets: create-tls-secret1 create-tls-secret2

remove-tls-secrets: remove-tls-secret1 remove-tls-secret2

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