MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean
SHELL := /bin/sh

#include ../../main/Makefile
include ../../main/versions.sh
include ../../main/vars.sh


#step 1
setup: 
	@rm -rf artifacts
	@mkdir -p artifacts/venafi-install
	@kubectl apply -f namespaces/aks-mesh-apps.yaml

#step 2
install-book-app:
	@kubectl -n aks-mesh-apps apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/platform/kube/bookinfo.yaml

#step 3
print-aks-svid: PODNAME=$$(kubectl get pods -n aks-mesh-apps -o jsonpath='{.items..metadata.name}' --selector app=ratings ) 
print-aks-svid:
	@echo "Pod name is ${PODNAME}"
	@istioctl -n aks-mesh-apps proxy-config secret ${PODNAME} \
	-o json | \
	jq -r '.dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes' | \
	base64 --decode | \
	openssl x509 -text -noout


#step 4
aks-mesh-prep:
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/helm/aks-istio-csr-values.yaml \
     > artifacts/venafi-install/istio-csr-values.yaml
	@kubectl apply -n aks-istio-system -f ../../main/templates/servicemesh/firefly-mesh-wi-issuer.yaml 

_create_sourceCA:
	@cp ${VEN_TRUST_ANCHOR_ROOT_CA_PEM} artifacts/venafi-install/venafi-trust-anchor-root-ca.pem
	@kubectl create secret generic venafi-trust-anchor --namespace='venafi' --from-file=ca.crt=artifacts/venafi-install/venafi-trust-anchor-root-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

#step 5
aks-mesh-trust-anchor: _create_sourceCA
	@echo "Creating Firefly trust anchor"
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < ../../main/templates/servicemesh/firefly-trust-anchor.yaml \
     > artifacts/venafi-install/firefly-trust-anchor.yaml
	@kubectl apply -n aks-istio-system -f artifacts/venafi-install/firefly-trust-anchor.yaml

#step 6
aks-install-istio-csr:
	@echo 'Installing Venafi istio CSR agent.....'
	@helm upgrade \
	    --install -f artifacts/venafi-install/istio-csr-values.yaml cert-manager-istio-csr \
  		--namespace venafi \
		oci://${VEN_CONTAINER_REGISTRY}/charts/cert-manager-istio-csr \
  		--version ${VEN_ISTIO_CSR_VERSION} \
		--wait

aks-cleanup: delete-book-app
	@helm uninstall -n venafi cert-manager-istio-csr || true
	@kubectl delete -n aks-istio-system -f artifacts/venafi-install/firefly-trust-anchor.yaml || true
	@kubectl delete -n aks-istio-system -f templates/servicemesh/firefly-mesh-wi-issuer.yaml || true
	@kubectl delete -f namespaces/aks-mesh-apps.yaml || true

delete-book-app: 
	@kubectl -n aks-mesh-apps delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/platform/kube/bookinfo.yaml || true


get_istio_label:
	@az aks show --resource-group aks1_group --name aks1  --query 'serviceMeshProfile.istio.revisions'


check-logs:
	@kubectl logs deploy/istiod-asm-1-19 -c discovery -n aks-istio-system | grep -v validationController 
