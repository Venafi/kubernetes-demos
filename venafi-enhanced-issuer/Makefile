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


################## PREP KUBERNETES CLUSTER FOR Venafi Enhanced ISSUER #################
init: mkdirs create-namespaces configure-namespace

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


_create-config-map-with-PEM-to-access-TPP:
	@cp ${JS_VENAFI_TPP_CA_BUNDLE_PEM_FILE} artifacts/venafi-enhanced/config/venafi-server-ca.pem
	@kubectl create configmap venafi-tpp-ca-bundle --namespace='jetstack-secure' --from-file=ca.crt=artifacts/venafi-enhanced/config/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

install-jetstack-venafi-enhanced-issuer-module: init _create-config-map-with-PEM-to-access-TPP
	@echo 'Setting up helm with the correct repos'
	@helm repo update
	@echo 'Installing Venafi Jetstack Venafi Enhanced Issuer Module.....'
	
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/values.yaml \
     > artifacts/venafi-enhanced/config/values.yaml

	@helm upgrade \
		--install -f artifacts/venafi-enhanced/config/values.yaml js \
		--namespace jetstack-secure \
		oci://${JS_CONTAINER_REGISTRY}/charts/venafi-enhanced-issuer \
	    --version ${JS_VENAFI_ENHANCED_ISSUER_VERSION} \
		--wait
################## END PREP KUBERNETES CLUSTER FOR Venafi Enhanced ISSUER #################

################## CREATE ISSUERS AND CLUSTER ISSUERS USING KUBERNETES SECRETS #################


create-rbac-for-connections:
	@kubectl apply -f templates/vtpp-connection-rbac.yaml

create-vtpp-secret: 
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vtpp-secret.yaml \
     > artifacts/venafi-enhanced/config/vtpp-secret.yaml
	@kubectl apply -f artifacts/venafi-enhanced/config/vtpp-secret.yaml

create-venafi-connection-acess-token:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vtpp-sandbox-connection.yaml \
     > artifacts/venafi-enhanced/config/vtpp-sandbox-connection.yaml
	@kubectl apply -f artifacts/venafi-enhanced/config/vtpp-sandbox-connection.yaml	

create-venafi-connection-user-password:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vtpp-cluster-connection.yaml \
     > artifacts/venafi-enhanced/config/vtpp-cluster-connection.yaml
	@kubectl apply -f artifacts/venafi-enhanced/config/vtpp-cluster-connection.yaml

create-venafi-issuer: create-rbac-for-connections create-vtpp-secret create-venafi-connection-acess-token
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vtpp-sandbox-issuer.yaml \
     > artifacts/venafi-enhanced/config/vtpp-sandbox-issuer.yaml
	@kubectl apply -f artifacts/venafi-enhanced/config/vtpp-sandbox-issuer.yaml

create-venafi-cluster-issuer: create-rbac-for-connections create-vtpp-secret create-venafi-connection-user-password
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vtpp-cluster-issuer.yaml \
     > artifacts/venafi-enhanced/config/vtpp-cluster-issuer.yaml
	@kubectl apply -f artifacts/venafi-enhanced/config/vtpp-cluster-issuer.yaml


create-cert-policy:
	@kubectl apply -f templates/cert-policy-and-rbac.yaml

create-sample-certs:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/sample-cert.yaml \
     > artifacts/venafi-enhanced/config/sample-cert.yaml
	@kubectl apply -f artifacts/venafi-enhanced/config/sample-cert.yaml


################## ENHANCED ISSUER WITH VAULT #################

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

	 make configure-vault configure-vault-policy mount-tpp-secret

create-service-account-for-vault:
	@kubectl apply -f templates/vault/vault-service-account.yaml

create-rbac-for-vault-issuers:
	@kubectl apply -f templates/vault/vault-issuer-rbac.yaml

create-vtpp-venafi-connection-with-vault: 
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vault/vault-vtpp-connection.yaml \
     > artifacts/venafi-enhanced/config/vault-vtpp-connection.yaml
	@kubectl apply -f artifacts/venafi-enhanced/config/vault-vtpp-connection.yaml

create-vtpp-venafi-issuer-with-vault: 
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vault/vault-vtpp-issuers.yaml \
     > artifacts/venafi-enhanced/config/vault-vtpp-issuers.yaml
	@kubectl apply -f artifacts/venafi-enhanced/config/vault-vtpp-issuers.yaml


create-cert-policy-vault:
	@kubectl apply -f templates/vault/cert-policy-and-rbac.yaml

create-sample-certs-vault:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/vault/sample-cert.yaml \
     > artifacts/venafi-enhanced/config/sample-cert-vault.yaml
	@kubectl apply -f artifacts/venafi-enhanced/config/sample-cert-vault.yaml


################## Remove Enhanced Issuer and Connections using Secrets#################


remove-rbac-for-connections:
	@kubectl delete -f templates/vtpp-connection-rbac.yaml || true

remove-vtpp-secret: 
	@kubectl delete -f artifacts/venafi-enhanced/config/vtpp-secret.yaml || true

remove-venafi-connection-acess-token:
	@kubectl delete -f artifacts/venafi-enhanced/config/vtpp-connection-access-token.yaml || true	

remove-venafi-connection-user-password:
	@kubectl delete -f artifacts/venafi-enhanced/config/vtpp-connection-user-pass.yaml || true

remove-venafi-issuer:
	@kubectl delete -f artifacts/venafi-enhanced/config/vtpp-issuer.yaml || true

remove-venafi-cluster-issuer:
	@kubectl delete -f artifacts/venafi-enhanced/config/vtpp-cluster-issuer.yaml || true 


remove-sample-certs:
	@kubectl delete -f artifacts/venafi-enhanced/config/sample-cert.yaml || true

remove-cert-policy:
	@kubectl delete -f templates/cert-policy-and-rbac.yaml || true

################## Remove Enhanced Issuer and Connections using Vault#################


remove-service-account-for-vault:
	@kubectl delete -f templates/vault/vault-service-account.yaml || true

remove-rbac-for-vault-issuers:
	@kubectl delete -f templates/vault/vault-issuer-rbac.yaml || true

remove-vtpp-venafi-connection-with-vault: 
	@kubectl delete -f artifacts/venafi-enhanced/config/vault-vtpp-connection.yaml || true

remove-vtpp-venafi-issuer-with-vault: 
	@kubectl delete -f artifacts/venafi-enhanced/config/vault-vtpp-issuers.yaml || true

remove-cert-policy-vault:
	@kubectl delete -f templates/vault/cert-policy-and-rbac.yaml || true

remove-sample-certs-vault:
	@kubectl delete -f artifacts/venafi-enhanced/config/sample-cert-vault.yaml || true

################## Common #################

remove-jetstack-venafi-enhanced-issuer-module:
	@echo 'Uninstalling Venafi Enhanced Issuer Module.....'
	@helm uninstall -n jetstack-secure js || true

################## Clean Up #################

cleanup-enhanced-issuer: remove-cert-policy remove-sample-certs remove-venafi-cluster-issuer remove-venafi-issuer remove-venafi-connection-user-password remove-venafi-connection-acess-token remove-vtpp-secret remove-rbac-for-connections

cleanup-enhanced-issuer-vault: remove-sample-certs-vault remove-cert-policy-vault remove-vtpp-venafi-issuer-with-vault remove-vtpp-venafi-connection-with-vault remove-rbac-for-vault-issuers remove-service-account-for-vault