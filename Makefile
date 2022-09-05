MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean 
SHELL := /bin/sh

# Include personal settings
include settings.sh

fresh-start: create-cluster create-cas cluster-addons

create-cluster:
	@$(MAKE) -C scripts create-gke-cluster --warn-undefined-variables

create-cas:
	@$(MAKE) -C scripts create-google-cas --warn-undefined-variables

_remove-cluster:
	@$(MAKE) -C scripts remove-gke-cluster --warn-undefined-variables

gcp-full-cleanup: clean-up-terraform _remove-cluster
	@$(MAKE) -C scripts remove-google-cas --warn-undefined-variables

cluster-addons: install-jetstack-approver-policy-module

install-vault-in-cluster: clean-up-terraform
	@echo 'Installing Vault...'
	
	@helm upgrade --install vault hashicorp/vault -n vault --create-namespace --set "server.dev.enabled=true" --wait
	@echo "Waiting for Vault to be ready !!!... "
	@kubectl wait pods -n vault -l app.kubernetes.io/name=vault --for condition=Ready --timeout=90s
	@echo 'Setting up port-forward to configure Jetstack Demo CA'
	@kubectl port-forward vault-0 18200:8200 -n vault &
	@echo 'Running Terraform......'
	@cd scripts/vault/terraform && terraform init
	@cd scripts/vault/terraform && terraform apply -auto-approve
	@echo 'Stopping port-forward'
	@pkill -f "kubectl port-forward vault-0" || true
	@echo 'Creating CA chain secret'
	#@kubectl create secret generic root-cert --from-file=ca.pem=scripts/vault/terraform/ca.pem -n jetstack-secure || true

clean-up-terraform:
	@rm -rf scripts/vault/terraform/.terraform
	@rm -rf scripts/vault/terraform/.terraform.lock.hcl
	@rm -rf scripts/vault/terraform/ca.pem
	@rm -rf scripts/vault/terraform/terraform.tfstate
	@rm -rf scripts/vault/terraform/terraform.tfstate.backup

# Not installed by default. This is a version with auto-approver turned off.
install-cert-manager-in-cluster:
	@$(MAKE) -C enterprise-cert-manager init --warn-undefined-variables
	@$(MAKE) -C enterprise-cert-manager install-cert-manager --warn-undefined-variables

_install-cert-manager-in-cluster-without-auto-approver:
	@$(MAKE) -C enterprise-cert-manager init --warn-undefined-variables
	@$(MAKE) -C enterprise-cert-manager install-cert-manager-without-auto-approver --warn-undefined-variables

install-jetstack-approver-policy-module: _install-cert-manager-in-cluster-without-auto-approver
	@$(MAKE) -C certificate-approver install-jetstack-approver-policy-module --warn-undefined-variables

install-cert-sync-to-venafi-module:
	@$(MAKE) -C cert-sync-to-venafi init --warn-undefined-variables
	@$(MAKE) -C cert-sync-to-venafi install-certificate-sync-module --warn-undefined-variables

install-cert-manager-CSI-driver:
	@$(MAKE) -C cert-manager-csi init --warn-undefined-variables
	@$(MAKE) -C cert-manager-csi install-cert-manager-csi-driver --warn-undefined-variables

install-google-cas-issuer-in-cluster:
	@echo "TBD"

remove-google-cas-issuer-module:
	@echo "TBD"

remove-jetstack-approver-policy-module:
	@$(MAKE) -C certificate-approver remove-jetstack-approver-policy-module --warn-undefined-variables

remove-vault:
	@helm uninstall vault -n vault
	@kubectl delete ns vault

remove-jetstack-cert-manager: remove-vault 
	@$(MAKE) -C enterprise-cert-manager remove-cert-manager --warn-undefined-variables
