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
	@mkdir -p artifacts/csi-driver/venafi
	@mkdir -p artifacts/pod-identities
	@mkdir -p artifacts/csi-driver/selfsigned

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

install-cert-manager-csi-driver: 
	@echo 'Setting up helm with the correct repos'
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo update
	@echo 'Installing Jetstack cert-manager CSI Driver.....'

	@helm upgrade \
		--install -f csi-driver/values.yaml cert-manager-csi-driver \
		--namespace jetstack-secure \
		oci://eu.gcr.io/jetstack-secure-enterprise/charts/cert-manager-csi-driver \
		--version ${JS_CERT_MANAGER_CSI_DRIVER_VERSION}
		--wait

create-policy-and-rbac:
	@cp templates/cert-policy-and-rbac-self-signed.yaml artifacts/csi-driver/selfsigned/cert-policy-and-rbac-self-signed.yaml
	@kubectl apply -f artifacts/csi-driver/selfsigned/cert-policy-and-rbac-self-signed.yaml

create-sample-app:
	@kubectl apply -f https://raw.githubusercontent.com/cert-manager/csi-driver/main/deploy/example/example-app.yaml

_create-config-map-with-PEM-to-access-TPP:
	@cp ${JS_VENAFI_TPP_CA_BUNDLE_PEM_FILE} artifacts/csi-driver/venafi/venafi-server-ca.pem
	@kubectl create configmap venafi-tpp-ca-bundle --namespace='jetstack-secure' --from-file=ca.crt=artifacts/csi-driver/venafi/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

_create-tpp-access-secret-for-policy:
	@kubectl create secret generic access-token --namespace='jetstack-secure' --from-literal=access-token='${JS_VENAFI_TPP_ACCESS_TOKEN}' --dry-run=client --save-config=true -o yaml | kubectl apply -f -

_create-issuer-and-policy-for-redis-app: _create-tpp-access-secret-for-policy _create-config-map-with-PEM-to-access-TPP
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/issuer-for-redis-app.yaml \
     > artifacts/csi-driver/venafi/issuer-for-redis-app.yaml
	kubectl apply -f artifacts/csi-driver/venafi/issuer-for-redis-app.yaml

	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/redis-certs-policy-and-rbac.yaml \
     > artifacts/csi-driver/venafi/redis-certs-policy-and-rbac.yaml
	@kubectl apply -f artifacts/csi-driver/venafi/redis-certs-policy-and-rbac.yaml

deploy-redis-app: _create-issuer-and-policy-for-redis-app
	@cp templates/redis-server.yaml artifacts/pod-identities/redis-server.yaml
	@cp templates/redis-client.yaml artifacts/pod-identities/redis-client.yaml
	@kubectl apply -f artifacts/pod-identities/redis-server.yaml
	@kubectl apply -f artifacts/pod-identities/redis-client.yaml

_remove-redis-rbac-policy-and-issuer:
	@kubectl delete -f artifacts/csi-driver/venafi/redis-certs-policy-and-rbac.yaml || true
	@kubectl delete -f artifacts/csi-driver/venafi/issuer-for-redis-app.yaml || true

remove-redis-app: _remove-redis-rbac-policy-and-issuer
	@kubectl delete -f artifacts/pod-identities/redis-server.yaml || true
	@kubectl delete -f artifacts/pod-identities/redis-client.yaml || true

remove-policy-and-rbac:
	@kubectl delete -f artifacts/csi-driver/selfsigned/cert-policy-and-rbac-self-signed.yaml || true

remove-sample-app:
	@kubectl delete -f https://raw.githubusercontent.com/cert-manager/csi-driver/main/deploy/example/example-app.yaml || true

remove-cert-manager-csi-driver: remove-redis-app _remove-redis-rbac-policy-and-issuer remove-policy-and-rbac remove-sample-app
	@echo 'Uninstalling Jetstack Enterprise cert-manager CSI Driver'
	@helm uninstall -n jetstack-secure cert-manager-csi-driver || true
