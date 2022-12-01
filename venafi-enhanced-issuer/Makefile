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
	@mkdir -p artifacts/venafi-enhanced
	@mkdir -p artifacts/venafi-enhanced/config


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

_create-config-map-with-PEM-to-access-TPP:
	@cp ${JS_VENAFI_TPP_CA_BUNDLE_PEM_FILE} artifacts/venafi-enhanced/config/venafi-server-ca.pem
	@kubectl create configmap venafi-tpp-ca-bundle --namespace='jetstack-secure' --from-file=ca.crt=artifacts/venafi-enhanced/config/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

install-jetstack-venafi-enhanced-issuer-module: _create-config-map-with-PEM-to-access-TPP
	@echo 'Setting up helm with the correct repos'
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo update
	@echo 'Installing Venafi Jetstack Venafi Enhanced Issuer Module.....'
	
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/values.yaml \
     > artifacts/venafi-enhanced/config/values.yaml

	@helm upgrade \
		--install -f artifacts/venafi-enhanced/config/values.yaml js \
		--namespace jetstack-secure \
		oci://eu.gcr.io/jetstack-secure-enterprise/charts/venafi-enhanced-issuer \
	    --version ${JS_VENAFI_ENHANCED_ISSUER_VERSION} \
		--wait

install-hashicorp-vault:
	@echo 'Setting up helm with the correct repos'
	@helm repo add vault https://helm.releases.hashicorp.com
	@helm repo update
	@echo 'Installing Hashicorp Vault'

	@helm upgrade vault vault \
		--install \
		--create-namespace \
		--wait \
		--namespace vault \
		--repo https://helm.releases.hashicorp.com \
		--values templates/vault/vault-values.yaml

create-rbac-for-issuers:
	@kubectl apply -f templates/venafi-enhanced-issuer-rbac.yaml

create-vtpp-venafi-issuer-and-secret: 
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vtpp-secret-venafi-issuer.yaml \
     > artifacts/venafi-enhanced/config/vtpp-secret-venafi-issuer.yaml
	@kubectl apply -f artifacts/venafi-enhanced/config/vtpp-secret-venafi-issuer.yaml

create-cert-policy:
	@kubectl apply -f templates/cert-policy-and-rbac.yaml

create-sample-certs:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/sample-cert.yaml \
     > artifacts/venafi-enhanced/config/sample-cert.yaml
	@kubectl apply -f artifacts/venafi-enhanced/config/sample-cert.yaml


configure-vault:
	@kubectl exec -n vault pods/vault-0 -- \
	 vault auth enable -path=jetstack-secure kubernetes

	@kubectl exec -n vault pods/vault-0 -- \
     vault write auth/jetstack-secure/config kubernetes_host=${JS_KUBERNETES_HOST}

	@kubectl exec -n vault pods/vault-0 -- \
	 vault write auth/jetstack-secure/role/application-team-1 \
   	 bound_audiences=vault.vault.svc.cluster.local \
     bound_service_account_names=application-team-1 \
     bound_service_account_namespaces=jetstack-secure \
     policies=application-team-1-readonly \
     ttl=5m

	@kubectl exec -n vault pods/vault-0 -- \
	 vault write auth/jetstack-secure/role/application-team-2 \
   	 bound_audiences=vault.vault.svc.cluster.local \
     bound_service_account_names=application-team-2 \
     bound_service_account_namespaces=sandbox \
     policies=application-team-2-readonly \
     ttl=5m


configure-vault-policy:
	@kubectl exec -i -n vault pods/vault-0 -- \
     vault policy write application-team-1-readonly - < templates/vault/vault-policy-team-1.hcl
	
	@kubectl exec -i -n vault pods/vault-0 -- \
     vault policy write application-team-2-readonly - < templates/vault/vault-policy-team-2.hcl

mount-tpp-secret:
	@kubectl exec -n vault pods/vault-0 -- \
     vault kv put -mount=secret application-team-1/tpp-username-password username=${JS_VENAFI_TPP_USERNAME} password=${JS_VENAFI_TPP_PASSWORD}
	
	@kubectl exec -n vault pods/vault-0 -- \
     vault kv put -mount=secret application-team-2/tpp-username-password username=${JS_VENAFI_TPP_USERNAME} password=${JS_VENAFI_TPP_PASSWORD}

create-service-account-for-vault:
	@kubectl apply -f templates/vault/vault-service-account.yaml

create-rbac-for-vault-issuers:
	@kubectl apply -f templates/vault/vault-issuer-rbac.yaml


create-vtpp-venafi-issuer-with-vault: 
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vault/vault-vtpp-enhanced-issuer.yaml \
     > artifacts/venafi-enhanced/config/vault-vtpp-enhanced-issuer.yaml
	@kubectl apply -f artifacts/venafi-enhanced/config/vault-vtpp-enhanced-issuer.yaml


create-cert-policy-vault:
	@kubectl apply -f templates/vault/cert-policy-and-rbac.yaml

create-sample-certs-vault:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vault/sample-cert.yaml \
     > artifacts/venafi-enhanced/config/sample-cert-vault.yaml
	@kubectl apply -f artifacts/venafi-enhanced/config/sample-cert-vault.yaml

remove-sample-certs-vault:
	@kubectl delete -f artifacts/venafi-enhanced/config/sample-cert-vault.yaml || true

remove-vtpp-venafi-issuer-with-vault: 
	@kubectl delete -f artifacts/venafi-enhanced/config/vault-vtpp-enhanced-issuer.yaml || true

remove-rbac-for-vault-issuers:
	@kubectl delete -f templates/vault-issuer-rbac.yaml || true

remove-service-account-for-vault:
	@kubectl delete -f templates/vault-service-account.yaml || true

remove-vtpp-venafi-issuer-and-secret:
	@kubectl delete -f templates/vtpp-secret-venafi-issuer.yaml || true

remove-rbac-for-issuers:
	@kubectl delete -f templates/venafi-enhanced-issuer-rbac.yaml || true

remove-sample-certs:
	@kubectl delete -f artifacts/venafi-enhanced/config/sample-cert.yaml || true

remove-jetstack-venafi-enhanced-issuer-module:
	@echo 'Uninstalling Venafi Enhanced Issuer Module.....'
	@helm uninstall -n jetstack-secure js || true

remove-cert-policy:
	@kubectl delete -f templates/cert-policy-and-rbac.yaml

remove-hashicorp-vault: 
	@helm uninstall -n vault vault || true

clean: remove-rbac-for-issuers remove-vtpp-venafi-issuer-and-secret remove-cert-policy remove-sample-certs remove-jetstack-venafi-enhanced-issuer-module

