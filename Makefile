MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean 
SHELL := /bin/sh

# Include personal settings
include settings.sh

fresh-start: create-cluster create-cas install-vault-in-cluster install-cert-manager-in-cluster

create-cluster:
	@$(MAKE) -C scripts create-gke-cluster --warn-undefined-variables

create-cas:
	@$(MAKE) -C scripts create-google-cas --warn-undefined-variables

_remove-cluster:
	@$(MAKE) -C scripts remove-gke-cluster --warn-undefined-variables

gcp-full-cleanup: _remove-cluster
	@$(MAKE) -C scripts remove-google-cas --warn-undefined-variables

install-vault-in-cluster:
	@helm repo add hashicorp https://helm.releases.hashicorp.com
	@helm repo update
	@helm upgrade --install vault hashicorp/vault -n vault --create-namespace --set "server.dev.enabled=true"

install-cert-manager-in-cluster:
	@$(MAKE) -C enterprise-cert-manager init --warn-undefined-variables
	@$(MAKE) -C enterprise-cert-manager install-cert-manager --warn-undefined-variables