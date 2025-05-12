MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean
SHELL := /bin/sh

include vars.sh

#Suffix for auto generated resources
gen_timestamp:
	@echo $$(date +%S%H%M%d%m) > artifacts/resource-suffix.txt

RESOURCE_SUFFIX ?= $(shell cat artifacts/resource-suffix.txt)

# Install venctl if the preferred mode of interacting with Venafi Control Plane is CLI. This will install
# venctl in /usr/local/bin . Tested on MacOS ARM
install-venctl:
	@curl -sSfL https://dl.venafi.cloud/venctl/latest/installer.sh | bash


_init: mkdirs gen_timestamp create-vcp-service-account create-namespaces configure-namespace

init: _init prep-helm-values

mkdirs:
	@rm -rf artifacts
	@mkdir -p artifacts/cyberark-install
	@mkdir -p artifacts/config
	@mkdir -p artifacts/samples

create-namespaces:
	@kubectl apply -f namespaces/cyberark.yaml
	@kubectl apply -f namespaces/sandbox.yaml

create-vcp-service-account: create-sa-for-registry create-sa-for-firefly

configure-namespace: create-registry-secret create-firefly-secret

#### Create image pull secret - BEGIN

create-sa-for-registry:
	@echo "Creating Service Account in Venafi Control Plane for registry secret"
	@venctl iam service-account registry create \
		--name "kongmesh-secret-${RESOURCE_SUFFIX}" \
		--output-file "artifacts/cyberark-install/cybr_mis_registry_secret.json" \
		--output "secret" \
		--owning-team "${CYBR_TEAM_NAME}" \
		--validity 10 \
		--scopes enterprise-cert-manager \
		--api-key ${CYBR_CLOUD_API_KEY}

create-registry-secret: _transform_registry_secret_to_yaml
	@echo "Credentials for venafi registry"
	@kubectl -n cyberark apply -f artifacts/cyberark-install/cybr_mis_registry_secret.yaml || true

_transform_registry_secret_to_yaml:
	@jq -r '.image_pull_secret' artifacts/cyberark-install/cybr_mis_registry_secret.json > artifacts/cyberark-install/cybr_mis_registry_secret.yaml

#### Create image pull secret - END

#### Create Firefly Service Account - BEGIN

create-sa-for-firefly:
	@echo "Creating Service account in Venafi Control Plane for Firefly"
	@venctl iam service-accounts firefly create \
	--name "kongmesh-firefly-${RESOURCE_SUFFIX}" \
	--output-file "artifacts/cyberark-install/cybr_mis_firefly_secret.json" \
	--output "secret" \
	--owning-team "${CYBR_TEAM_NAME}" \
	--validity 10 \
	--api-key ${CYBR_CLOUD_API_KEY}

create-firefly-secret: _transform_firefly_secret_to_yaml
	@echo "Credentials for Firefly"
	@kubectl -n cyberark apply -f artifacts/cyberark-install/cybr_mis_firefly_secret.yaml || true

_transform_firefly_secret_to_yaml:
	@echo "Credentials for Venafi Firefly"
	@jq -r '.private_key' artifacts/cyberark-install/cybr_mis_firefly_secret.json > artifacts/cyberark-install/cybr_mis_firefly_secret.yaml
	@jq -r '.client_id' artifacts/cyberark-install/cybr_mis_firefly_secret.json > artifacts/cyberark-install/cybr_mis_firefly_client_id.txt

#### Create Firefly Service Account - END
CYBR_FIREFLY_SA_CLIENT_ID ?= $(shell cat artifacts/cyberark-install/cybr_mis_firefly_client_id.txt)

prep-helm-values:
	@cp templates/helm/firefly-values.yaml artifacts/cyberark-install/firefly-values.yaml
#	@cat templates/helm/firefly-values.yaml | sed -e "s/REPLACE_CLIENT_ID/${CYBR_FIREFLY_SA_CLIENT_ID}/g" > artifacts/cyberark-install/firefly-values.yaml

generate-venafi-manifests:
	@echo "Generating Venafi Helm manifests for installation"
	@venctl components kubernetes manifest generate \
		--namespace cyberark \
		--cert-manager \
		--accept-firefly-tos \
		--firefly \
		--firefly-values-files firefly-values.yaml \
		--default-approver \
		--image-pull-secret-names venafi-image-pull-secret  > artifacts/cyberark-install/venafi-manifests.yaml

install: check-config
	@FIREFLY_VENAFI_CLIENT_ID=${CYBR_FIREFLY_SA_CLIENT_ID} \
		venctl components kubernetes manifest tool sync --file artifacts/cyberark-install/venafi-manifests.yaml 


check-config:
	@while [ -z "$$CONFIRM" ]; do \
		read -r -p "Have you attached the Firefly service account to your config in the UI? [y/N] " CONFIRM; \
	done ; \
	if [ ! $$CONFIRM == "y" ]; then \
	if [ ! $$CONFIRM == "Y" ]; then \
		echo "######################################################################\n" \
		echo "The Firefly Config in the UI needs to be associated with the service\n" \
		echo "account name that maps to client id ${CYBR_FIREFLY_SA_CLIENT_ID}\n" \
		echo "######################################################################" ; exit 1 ; \
	fi \
	fi

create-firefly-sample-certs:
	@kubectl apply -f samples/sample-firefly-certificates.yaml

#create-cyberark-policy:
#	@kubectl apply -f templates/cyberark-policy.yaml

setup-kyverno: install-kyverno wait-for-kyverno create-kyverno-policy
setup-kong-mesh: install-kong-mesh wait-for-kong-mesh setup-traffic-permissons configure-kong-with-firefly create-sample-app wait-for-sample-app

install-kyverno:
	@kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.11.1/install.yaml

wait-for-kyverno:
	@kubectl wait -n kyverno \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/instance=kyverno \
		--timeout=90s

create-kyverno-policy:
	@kubectl apply -f templates/kyverno/cluster-policy.yaml



install-kong-mesh:
	@helm repo add kong-mesh https://kong.github.io/kong-mesh-charts
	@helm repo update
	@helm install --create-namespace \
				  --namespace kong-mesh-system \
				  kong-mesh kong-mesh/kong-mesh \
				  --version 2.10.1 \
				  --wait

wait-for-kong-mesh:
	@kubectl wait -n kong-mesh-system \
		--for=condition=ready pod \
		--selector=app=kong-mesh-control-plane \
		--timeout=90s

setup-traffic-permissons:
	@kubectl apply -f templates/kong/mesh-traffic-permission.yaml

configure-kong-with-firefly:
	@kubectl apply -f templates/kong/mesh.yaml


create-sample-app:
	@kubectl apply -f https://raw.githubusercontent.com/kumahq/kuma-counter-demo/master/demo.yaml

wait-for-sample-app:
	@kubectl wait -n kuma-demo \
		--for=condition=ready pod \
		--selector=app=demo-app \
		--timeout=90s

print-kong-svid:
	@kumactl inspect dataplane \
  		$$(kubectl get pods -l app=demo-app -n kuma-demo -o jsonpath="{.items[*].metadata.name}").kuma-demo --type=config-dump | \
  		jq -r '.configs[5].dynamic_active_secrets[] | select(.name == "identity_cert:secret:default") | \
  		.secret.tls_certificate.certificate_chain.inline_bytes' | base64 -d | openssl x509 -noout -text

_delete-sample-app:
	@kubectl delete -f https://raw.githubusercontent.com/kumahq/kuma-counter-demo/master/demo.yaml || true

_remove-firefly-config:
	@kubectl delete -f templates/kong/mesh.yaml || true

_remove-mtp:
	@kubectl delete -f templates/kong/mesh-traffic-permission.yaml || true

uninstall-kong-mesh: _delete-sample-app _remove-firefly-config _remove-mtp
	@helm uninstall --namespace kong-mesh-system kong-mesh || true
	@kubectl delete ns kong-mesh-system || true
	
_remove-kyverno-policy: 
	@kubectl delete -f templates/kyverno/cluster-policy.yaml || true

uninstall-kyverno: _remove-kyverno-policy
	@kubectl delete -f https://github.com/kyverno/kyverno/releases/download/v1.11.1/install.yaml || true

_remove-sample-certs:
	@kubectl delete -f samples/sample-firefly-certificates.yaml || true
	@kubectl delete -f templates/cyberark-policy.yaml || true

uninstall-cyberark: _remove-sample-certs 
		@FIREFLY_VENAFI_CLIENT_ID=${CYBR_FIREFLY_SA_CLIENT_ID} \
		venctl components kubernetes manifest tool destroy --file artifacts/cyberark-install/venafi-manifests.yaml 

clean-all: uninstall-kong-mesh uninstall-kyverno uninstall-cyberark
	@kubectl delete ns sandbox || true
	@kubectl delete ns cyberark || true
	@kubectl get crds | grep 'kuma.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true
	@kubectl get crds | grep 'cert-manager.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true
	@kubectl get crds | grep 'jetstack.io' |   xargs -n1 -I{} sh -c "kubectl delete crd {}" || true

kong-cp:
	@kubectl port-forward svc/kong-mesh-control-plane -n kong-mesh-system 5681:5681

kong-dp:
	@kubectl port-forward svc/demo-app -n kuma-demo 5000:5000