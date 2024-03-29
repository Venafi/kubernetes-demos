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
	@mkdir -p artifacts/isolated-issuer
	@mkdir -p artifacts/isolated-issuer/venafi

################## PREP KUBERNETES CLUSTER FOR ISOLATED ISSUER #################
init: mkdirs make-namespaces create-crds

make-namespaces:
	@kubectl apply -f namespaces/sandbox.yaml

create-crds:
	@kubectl apply -f https://platform.jetstack.io/documentation/installation/isolated-issuer/cert-manager/approve/${JS_ISOLATED_ISSUER_VERSION}/cert-manager-isolated-issuer-crd.yaml
	@kubectl apply -f https://platform.jetstack.io/documentation/installation/isolated-issuer/cert-manager/approve/${JS_ISOLATED_ISSUER_VERSION}/cert-manager-isolated-issuer-rbac.yaml

create-kubeconfig:
	@cp ~/.kube/config kubeconfig-for-isolated-issuer
	@echo "################################# PRINTING KUBERNETES CONTEXTS ########################################"
	@kubectl config get-contexts --kubeconfig kubeconfig-for-isolated-issuer -o name 
	@echo "################################# PRINTING KUBERNETES CONTEXTS ########################################"
	@echo ""
	@echo "If kubeconfig-for-isolated-issuer has contexts that you do not want to share clean up kubeconfig"
	@echo "For each context that you do not need , run kubectl config delete-context --kubeconfig kubeconfig-for-isolated-issuer <context-name>"

_create-config-map-with-PEM-to-access-TPP:
	@cp ${JS_VENAFI_TPP_CA_BUNDLE_PEM_FILE} artifacts/isolated-issuer/venafi/venafi-server-ca.pem
	@kubectl create configmap venafi-tpp-ca-bundle --namespace='jetstack-secure' --from-file=ca.crt=artifacts/isolated-issuer/venafi/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

_create-tpp-access-secret-for-policy:
	@kubectl create secret generic access-token --namespace='jetstack-secure' --from-literal=access-token='${JS_VENAFI_TPP_ACCESS_TOKEN}' --dry-run=client --save-config=true -o yaml | kubectl apply -f -

create-venafi-tpp-certificate-policy: _create-config-map-with-PEM-to-access-TPP _create-tpp-access-secret-for-policy
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < config/venafi/cert-policy.yaml \
     > artifacts/isolated-issuer/venafi/cert-policy.yaml
	@kubectl apply -f artifacts/isolated-issuer/venafi/cert-policy.yaml
	@kubectl apply -f config/venafi/cert-policy-rbac.yaml

################## PREP KUBERNETES CLUSTER FOR ISOLATED ISSUER #################


################## INSTRUCTIONS FOR SECURITY TEAM #####################

create-bootstrap-config-for-isolated-issuer:
	@echo "Generating isolated issuer configuration for Venafi TPP."

	@cp ${JS_VENAFI_INTERMEDIATE_CA_ROOT_PEM_FILE} artifacts/isolated-issuer/venafi/venafi-ica-root-ca.pem

	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < config/venafi/tpp-isolated_issuer_config-template.yaml \
     > artifacts/isolated-issuer/venafi/tpp-isolated_issuer_config.yaml
	@echo "Generating isolated issuer configuration for Venafi TPP................. DONE"
	@echo "Config available at artifacts/isolated-issuer/venafi/tpp-isolated_issuer_config.yaml"

download_isolated_issuer:
	@echo "Not publicly accessible at this time to download."

validate-issuer-config:
	@${JS_ISOLATED_ISSUER_BINARY} \
	--disable-mlock run validate \
	--config artifacts/isolated-issuer/venafi/tpp-isolated_issuer_config.yaml \
	--kubeconfig kubeconfig-for-isolated-issuer

print-run-command-for-isolated-issuer: validate-issuer-config
	@echo "After validation is successful, start the isolated issuer simply by running the following"
	@echo ${JS_ISOLATED_ISSUER_BINARY} \
	--disable-mlock true \
	run \
	--config artifacts/isolated-issuer/venafi/tpp-isolated_issuer_config.yaml \
	--kubeconfig kubeconfig-for-isolated-issuer
################## INSTRUCTIONS FOR SECURITY TEAM #####################


################ TESTING CERTIFICATE ISSUANCE ################
create-certificates:
	@kubectl apply -f config/venafi/cm_certificate.yaml

################ TESTING CERTIFICATE ISSUANCE ################

_remove-policy-and-rbac:
	@kubectl delete -f artifacts/isolated-issuer/venafi/cert-policy.yaml || true
	@kubectl delete -f config/venafi/cert-policy-rbac.yaml || true

_remove-crds:
	@kubectl delete -f https://platform.jetstack.io/documentation/installation/isolated-issuer/cert-manager/approve/${JS_ISOLATED_ISSUER_VERSION}/cert-manager-isolated-issuer-crd.yaml || true
	@kubectl delete -f https://platform.jetstack.io/documentation/installation/isolated-issuer/cert-manager/approve/${JS_ISOLATED_ISSUER_VERSION}/cert-manager-isolated-issuer-rbac.yaml || true

_remove-certificates:
	@kubectl delete -f config/venafi/cm_certificate.yaml || true

remove-isolated-issuer-config: _remove-certificates _remove-policy-and-rbac  _remove-crds

