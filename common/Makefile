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
	@mkdir -p artifacts

################## PREP KUBERNETES CLUSTER FOR ISOLATED ISSUER #################
init: mkdirs

# Create a Kubernetes secret resource
create-venafi-credentials:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/venafi-secret.yaml \
     > artifacts/venafi-secret.yaml
	@kubectl apply -f artifacts/venafi-secret.yaml

create-venafi-connection-rbac:
	@kubectl apply -f templates/venafi-connection-rbac.yaml

create-venafi-tpp-connection:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/venafi-tpp-connection.yaml \
     > artifacts/venafi-tpp-connection.yaml
	@kubectl apply -f artifacts/venafi-tpp-connection.yaml

create-venafi-cloud-connection:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/venafi-cloud-connection.yaml \
     > artifacts/venafi-cloud-connection.yaml
	@kubectl apply -f artifacts/venafi-cloud-connection.yaml

remove-venafi-credentials:
	@kubectl delete -f artifacts/venafi-secret.yaml || true

remove-venafi-connection-rbac:
	@kubectl delete -f templates/venafi-connection-rbac.yaml || true

remove-venafi-tpp-connection:
	@kubectl delete -f artifacts/venafi-tpp-connection.yaml || true

remove-venafi-cloud-connection:
	@kubectl delete -f artifacts/venafi-cloud-connection.yaml || true

clean: remove-venafi-cloud-connection remove-venafi-tpp-connection remove-venafi-connection-rbac remove-venafi-credentials
	

