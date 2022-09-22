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
	@mkdir -p artifacts/csi-driver-spiffe/venafi
	@mkdir -p artifacts/pod-identities
	@mkdir -p artifacts/csi-driver-spiffe/selfsigned

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

_create_sourceCA:
	@cp ${JS_VENAFI_INTERMEDIATE_CA_ROOT_PEM_FILE} artifacts/csi-driver-spiffe/venafi/venafi-ica-root-ca.pem
	@kubectl create secret generic spiffe-source-ca --namespace='jetstack-secure' --from-file=ca.crt=artifacts/csi-driver-spiffe/venafi/venafi-ica-root-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/trust-bundle.yaml \
     > artifacts/csi-driver-spiffe/venafi/trust-bundle.yaml
	kubectl apply -f artifacts/csi-driver-spiffe/venafi/trust-bundle.yaml

install-cert-manager-csi-driver-spiffe: _create_sourceCA
	@echo 'Setting up helm with the correct repos'
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo update
	@echo 'Installing Jetstack cert-manager CSI Driver.....'

	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/values.yaml \
     > artifacts/csi-driver-spiffe/values.yaml

	@helm upgrade \
		--install -f artifacts/csi-driver-spiffe/values.yaml cert-manager-csi-driver-spiffe jetstack/cert-manager-csi-driver-spiffe \
		--namespace jetstack-secure \
        --version ${JS_CERT_MANAGER_CSI_DRIVER_SPIFFE_VERSION}

_create-config-map-with-PEM-to-access-TPP:
	@cp ${JS_VENAFI_TPP_CA_BUNDLE_PEM_FILE} artifacts/csi-driver-spiffe/venafi/venafi-server-ca.pem
	@kubectl create configmap venafi-tpp-ca-bundle --namespace='jetstack-secure' --from-file=ca.crt=artifacts/csi-driver-spiffe/venafi/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

_create-tpp-access-secret-for-policy:
	@kubectl create secret generic access-token --namespace='jetstack-secure' --from-literal=access-token='${JS_VENAFI_TPP_ACCESS_TOKEN}' --dry-run=client --save-config=true -o yaml | kubectl apply -f -

create-spiffe-cluster-issuer: _create-tpp-access-secret-for-policy _create-config-map-with-PEM-to-access-TPP

	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/csi-spiffe-issuer.yaml \
     > artifacts/csi-driver-spiffe/venafi/csi-spiffe-issuer.yaml
	kubectl apply -f artifacts/csi-driver-spiffe/venafi/csi-spiffe-issuer.yaml

	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/cert-policy-for-venafi-ica.yaml \
     > artifacts/csi-driver-spiffe/venafi/cert-policy-for-venafi-ica.yaml
	@kubectl apply -f artifacts/csi-driver-spiffe/venafi/cert-policy-for-venafi-ica.yaml

deploy-redis-app: deploy-redis-server deploy-redis-client

deploy-redis-server:
	@cp templates/redis-server.yaml artifacts/pod-identities/redis-server.yaml
	@kubectl apply -f artifacts/pod-identities/redis-server.yaml

deploy-redis-client:
	@cp templates/redis-client.yaml artifacts/pod-identities/redis-client.yaml
	@kubectl apply -f artifacts/pod-identities/redis-client.yaml

remove-spiffe-cluster-issuer:
	@kubectl delete -f artifacts/csi-driver-spiffe/venafi/csi-spiffe-issuer.yaml || true
	@kubectl delete -f artifacts/csi-driver-spiffe/venafi/cert-policy-for-venafi-ica.yaml || true

remove-redis-app: remove-redis-server remove-redis-client

remove-redis-server:
	@kubectl delete -f artifacts/pod-identities/redis-server.yaml || true

remove-redis-client:
	@kubectl delete -f artifacts/pod-identities/redis-client.yaml || true
	
remove-trust-bundle:
	@kubectl delete -f artifacts/csi-driver-spiffe/venafi/trust-bundle.yaml || true

remove-cert-manager-csi-driver-spiffe: remove-redis-app remove-spiffe-cluster-issuer remove-trust-bundle
	@echo 'Uninstalling Jetstack Enterprise cert-manager CSI Driver SPIFFE'
	@helm uninstall -n jetstack-secure cert-manager-csi-driver-spiffe || true
	@kubectl delete secret spiffe-source-ca --namespace='jetstack-secure' || true

