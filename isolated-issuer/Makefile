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
prep-kubernetes: make-namespaces create-crds

make-namespaces:
	@kubectl apply -f namespaces/venafi-tpp.yaml

create-crds:
	@kubectl apply -f https://platform.jetstack.io/documentation/installation/isolated-issuer/cert-manager/approve/v0.0.1-alpha.2/cert-manager-isolated-issuer-crd.yaml
	@kubectl apply -f https://platform.jetstack.io/documentation/installation/isolated-issuer/cert-manager/approve/v0.0.1-alpha.2/cert-manager-isolated-issuer-rbac.yaml


create-kubeconfig:
	@cp ~/.kube/config kubeconfig-for-isolated-issuer
	@echo "################################# PRINTING KUBERNETES CONTEXTS ########################################"
	@kubectl config get-contexts --kubeconfig kubeconfig-for-isolated-issuer -o name 
	@echo "################################# PRINTING KUBERNETES CONTEXTS ########################################"
	@echo ""
	@echo "If kubeconfig-for-isolated-issuer has contexts that you do not want to share clean up kubeconfig"
	@echo "For each context that you do not need , run kubectl config delete-context --kubeconfig kubeconfig-for-isolated-issuer <context-name>"

################## PREP KUBERNETES CLUSTER FOR ISOLATED ISSUER #################


################## INSTRUCTIONS FOR SECURITY TEAM #####################

create-bootstrap-config-for-isolated-issuer:
	@echo "Generating isolated issuer configuration for Venafi TPP."
	@cp ${JS_VENAFI_PEM_ENCODED_CA_CHAIN_FILE_FOR_ISOLATED_ISSUER} artifacts/isolated-issuer/venafi

	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < config/venafi/tpp-isolated_issuer_config-template.yaml \
     > artifacts/isolated-issuer/venafi/tpp-isolated_issuer_config.yaml
	@echo "Generating isolated issuer configuration for Venafi TPP................. DONE"

validate-issuer-config:
	@~/sandbox/GitHub/isolated-issuer/bin/isolated-issuer \
	--disable-mlock \
	validate \
	--config artifacts/isolated-issuer/venafi/tpp-isolated_issuer_config.yaml \
	--kubeconfig kubeconfig-for-isolated-issuer

print-run-command-for-isolated-issuer: validate-issuer-config
	@echo "After validation is successful, start the isolated issuer simply by running the following"
	@echo "~/sandbox/GitHub/isolated-issuer/bin/isolated-issuer \
	--disable-mlock \
	run \
	--config artifacts/isolated-issuer/venafi/tpp-isolated_issuer_config.yaml" \
	--kubeconfig kubeconfig-for-isolated-issuer
################## INSTRUCTIONS FOR SECURITY TEAM #####################



################ TESTING CERTIFICATE ISSUANCE ################
create-certificate:
	@kubectl apply -f config/venafi/cm_certificate.yaml

################ TESTING CERTIFICATE ISSUANCE ################