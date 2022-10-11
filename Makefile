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

cluster-addons: install-jetstack-approver-policy-module install-cert-manager-trust-in-cluster

# this is called from service-mesh/istio Makefile if you choose Vault as the signer for mesh workloads.
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

clean-up-terraform:
	@rm -rf scripts/vault/terraform/.terraform
	@rm -rf scripts/vault/terraform/.terraform.lock.hcl
	@rm -rf scripts/vault/terraform/ca.pem
	@rm -rf scripts/vault/terraform/terraform.tfstate
	@rm -rf scripts/vault/terraform/terraform.tfstate.backup

_install-cert-manager-in-cluster-without-auto-approver:
	@$(MAKE) -C enterprise-cert-manager init --warn-undefined-variables
	@$(MAKE) -C enterprise-cert-manager install-cert-manager-without-auto-approver --warn-undefined-variables

install-jetstack-approver-policy-module: _install-cert-manager-in-cluster-without-auto-approver
	@$(MAKE) -C certificate-approver install-jetstack-approver-policy-module --warn-undefined-variables

install-cert-manager-trust-in-cluster:
	@$(MAKE) -C trust init --warn-undefined-variables
	@$(MAKE) -C trust install-cert-manager-trust --warn-undefined-variables

install-cert-sync-to-venafi-module:
	@$(MAKE) -C cert-sync-to-venafi init --warn-undefined-variables
	@$(MAKE) -C cert-sync-to-venafi install-certificate-sync-module --warn-undefined-variables

install-cert-manager-CSI-driver:
	@$(MAKE) -C cert-manager-csi init --warn-undefined-variables
	@$(MAKE) -C cert-manager-csi install-cert-manager-csi-driver --warn-undefined-variables

install-cert-manager-csi-driver-spiffe:
	@$(MAKE) -C cert-manager-csi-spiffe init --warn-undefined-variables
	@$(MAKE) -C cert-manager-csi-spiffe install-cert-manager-csi-driver-spiffe --warn-undefined-variables

install-jetstack-isolated-issuer-config:
	@$(MAKE) -C isolated-issuer init --warn-undefined-variables	

install-google-cas-issuer-in-cluster:
	@echo "TBD"

install-kms-issuer-in-cluster:
	@$(MAKE) -C external-issuers init --warn-undefined-variables
	@$(MAKE) -C external-issuers install-kms-issuer --warn-undefined-variables

remove-kms-issuer-module:
	@$(MAKE) -C external-issuers clean-kms --warn-undefined-variables

install-pca-issuer-in-cluster:
	@$(MAKE) -C external-issuers init --warn-undefined-variables
	@$(MAKE) -C external-issuers install-awspca-issuer --warn-undefined-variables

install-js-venafi-enhanced-issuer-module:
	@$(MAKE) -C venafi-enhanced-issuer init --warn-undefined-variables
	@$(MAKE) -C venafi-enhanced-issuer install-jetstack-venafi-enhanced-issuer-module --warn-undefined-variables

remove-js-venafi-enhanced-issuer-module:
	@$(MAKE) -C venafi-enhanced-issuer clean --warn-undefined-variables

remove-pca-issuer-module:
	@$(MAKE) -C external-issuers clean-pca --warn-undefined-variables

remove-google-cas-issuer-module:
	@echo "TBD"

remove-vault:
	@helm uninstall vault -n vault || true
	@kubectl delete ns vault || true

remove-jetstack-cert-manager: remove-vault 
	@$(MAKE) -C enterprise-cert-manager clean --warn-undefined-variables

remove-jetstack-approver-policy-module:
	@$(MAKE) -C certificate-approver clean --warn-undefined-variables

remove-jetstack-venafi-cert-sync-module:
	@$(MAKE) -C cert-sync-to-venafi remove-certificate-sync-module --warn-undefined-variables

remove-jetstack-cert-manager-csi-driver:
	@$(MAKE) -C cert-manager-csi remove-cert-manager-csi-driver --warn-undefined-variables

remove-jetstack-cert-manager-csi-driver-spiffe:
	@$(MAKE) -C cert-manager-csi-spiffe remove-cert-manager-csi-driver-spiffe --warn-undefined-variables

remove-istio-csr-and-demos: 
	@$(MAKE) -C service-mesh/istio cleanup --warn-undefined-variables

remove-jetstack-isolated-issuer-config:
	@$(MAKE) -C isolated-issuer remove-isolated-issuer-config --warn-undefined-variables	

remove-cert-manager-trust:
	@$(MAKE) -C trust clean --warn-undefined-variables

reset-cluster: remove-istio-csr-and-demos remove-jetstack-isolated-issuer-config remove-jetstack-cert-manager-csi-driver-spiffe remove-jetstack-cert-manager-csi-driver remove-jetstack-venafi-cert-sync-module remove-jetstack-approver-policy-module remove-kms-issuer-module remove-pca-issuer-module remove-cert-manager-trust remove-jetstack-cert-manager
	@echo ""
	@echo ""
	@echo ""
	@echo "#####################################################################"
	@echo "Cluster is reset. Start by running make cluster-addons to start fresh"
	@echo "#####################################################################"
