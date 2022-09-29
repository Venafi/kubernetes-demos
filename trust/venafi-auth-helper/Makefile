MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean
SHELL := /bin/sh

 # Include personal settings
 include ../settings.sh

mkdirs:
	@rm -rf artifacts
	@mkdir -p artifacts/vauth-helper/user
	@mkdir -p artifacts/vauth-helper/auth

init: mkdirs make-namespaces configure-namespace

make-namespaces:
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

install-vauth-helper-module: create-venafi-tpp-access-secret
	@echo 'Setting up helm with the correct repos'
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo update
	@echo 'Installing Venafi Jetstack Certificate Sync Module.....'
	@helm upgrade \
		--install -f vauth-helper/values.yaml vauth \
		oci://eu.gcr.io/jetstack-secure-enterprise/charts/venafi-oauth-helper \
		--wait \
		--namespace jetstack-secure \
		--version ${JS_VAUTH_HELPER_VERSION}


########################################################################################################################
# User Creds
########################################################################################################################

create-venafi-user-issuer:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/user/venafi-user-issuer.yaml \
     > artifacts/vauth-helper/user/venafi-user-issuer.yaml
	@kubectl apply -f artifacts/vauth-helper/user/venafi-user-issuer.yaml

create-vauth-bootstrap-secret-user:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/user/vauth-user-secret.yaml \
     > artifacts/vauth-helper/user/vauth-user-secret.yaml
	@kubectl apply -f artifacts/vauth-helper/user/vauth-user-secret.yaml

create-user-policy-credentials:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/user/venafi-policy-issuer.yaml \
     > artifacts/vauth-helper/user/venafi-policy-issuer.yaml
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/user/vauth-policy-secret.yaml \
     > artifacts/vauth-helper/user/vauth-policy-secret.yaml
	@kubectl apply -f artifacts/vauth-helper/user/venafi-policy-issuer.yaml
	@kubectl apply -f artifacts/vauth-helper/user/vauth-policy-secret.yaml

_create-config-map-with-PEM-to-access-TPP:
	@cp ${JS_VENAFI_TPP_CA_BUNDLE_PEM_FILE} artifacts/vauth-helper/venafi-server-ca.pem
	@kubectl create configmap venafi-tpp-ca-bundle --namespace='jetstack-secure' --from-file=ca.crt=artifacts/vauth-helper/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

create-venafi-tpp-voh-user-certificate-policy: _create-config-map-with-PEM-to-access-TPP 
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/user/cert-policy-user.yaml \
     > artifacts/vauth-helper/user/cert-policy-user.yaml
	@kubectl apply -f artifacts/vauth-helper/user/cert-policy-user.yaml
	@kubectl apply -f templates/user/cert-policy-rbac-user.yaml

create-venafi-tpp-voh-user-cert:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/user/sample-user-cert.yaml \
     > artifacts/vauth-helper/user/sample-user-cert.yaml
	@kubectl apply -f artifacts/vauth-helper/user/sample-user-cert.yaml

delete-venafi-user-issuer:
	@kubectl delete -f artifacts/vauth-helper/user/venafi-user-issuer.yaml

delete-vauth-bootstrap-secret-user:
	@kubectl delete -f artifacts/vauth-helper/user/vauth-user-secret.yaml

delete-user-policy-credentials:
	@kubectl delete -f artifacts/vauth-helper/user/venafi-policy-issuer.yaml
	@kubectl delete -f artifacts/vauth-helper/user/vauth-policy-secret.yaml

delete-venafi-tpp-voh-user-certificate-policy:
	@kubectl delete -f artifacts/vauth-helper/user/cert-policy-user.yaml
	@kubectl delete -f templates/user/cert-policy-rbac-user.yaml

delete-venafi-tpp-voh-user-cert:
	@kubectl delete -f artifacts/vauth-helper/user/sample-user-cert.yaml

clean-vauth-user: delete-venafi-tpp-voh-user-cert delete-policy-credentials delete-venafi-tpp-voh-user-certificate-policy delete-vauth-bootstrap-secret-user delete-venafi-user-issuer

########################################################################################################################
# Tokens
########################################################################################################################

create-venafi-auth-issuer:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/auth/venafi-auth-issuer.yaml \
     > artifacts/vauth-helper/auth/venafi-auth-issuer.yaml
	@kubectl apply -f artifacts/vauth-helper/auth/venafi-auth-issuer.yaml

create-vauth-bootstrap-secret-auth:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/auth/vauth-auth-secret.yaml \
     > artifacts/vauth-helper/auth/vauth-auth-secret.yaml
	@kubectl apply -f artifacts/vauth-helper/auth/vauth-auth-secret.yaml

create-auth-policy-credentials:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/auth/venafi-policy-issuer.yaml \
     > artifacts/vauth-helper/auth/venafi-policy-issuer.yaml
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/auth/vauth-policy-secret.yaml \
     > artifacts/vauth-helper/auth/vauth-policy-secret.yaml
	@kubectl apply -f artifacts/vauth-helper/auth/venafi-policy-issuer.yaml
	@kubectl apply -f artifacts/vauth-helper/auth/vauth-policy-secret.yaml

create-venafi-tpp-voh-auth-certificate-policy: _create-config-map-with-PEM-to-access-TPP 
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/auth/cert-policy-auth.yaml \
     > artifacts/vauth-helper/auth/cert-policy-auth.yaml
	@kubectl apply -f artifacts/vauth-helper/auth/cert-policy-auth.yaml
	@kubectl apply -f templates/auth/cert-policy-rbac-auth.yaml

create-venafi-tpp-voh-auth-cert:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/auth/sample-auth-cert.yaml \
     > artifacts/vauth-helper/auth/sample-auth-cert.yaml
	@kubectl apply -f artifacts/vauth-helper/auth/sample-auth-cert.yaml

delete-venafi-auth-issuer:
	@kubectl delete -f artifacts/vauth-helper/auth/venafi-auth-issuer.yaml

delete-vauth-bootstrap-secret-auth:
	@kubectl delete -f artifacts/vauth-helper/auth/vauth-auth-secret.yaml

delete-venafi-tpp-voh-auth-certificate-policy:
	@kubectl delete -f artifacts/vauth-helper/auth/cert-policy-auth.yaml
	@kubectl delete -f templates/auth/cert-policy-rbac-auth.yaml

delete-auth-policy-credentials:
	@kubectl delete -f artifacts/vauth-helper/auth/venafi-policy-issuer.yaml
	@kubectl delete -f artifacts/vauth-helper/auth/vauth-policy-secret.yaml

delete-venafi-tpp-voh-auth-cert:
	@kubectl delete -f artifacts/vauth-helper/auth/sample-auth-cert.yaml

clean-vauth-auth: delete-venafi-tpp-voh-auth-cert delete-policy-credentials delete-venafi-tpp-voh-auth-certificate-policy delete-vauth-bootstrap-secret-auth delete-venafi-auth-issuer

