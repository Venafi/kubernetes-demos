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
ifndef JS_VENAFI_CLOUD_API_KEY
	@(echo "JS_VENAFI_CLOUD_API_KEY not defined. "; exit 1)
endif 

#STEP1 . Setup the environment. This creates the temporary directories, creates namespaces and also configures namespace with DOCKER REGISTRY SECRET.
init: mkdirs make-namespaces configure-namespace 

mkdirs:
	@rm -rf artifacts
	@mkdir -p artifacts/firefly
	@mkdir -p artifacts/cert-manager

make-namespaces:
	@kubectl apply -f namespaces/sandbox.yaml
	@kubectl apply -f namespaces/venafi-tlspk.yaml

configure-namespace:
ifneq (${JS_AIRGAPPED},true)
	@echo "Creating docker registry secret. You must have the credentials file to create a secret"
	@echo
	@kubectl -n 'venafi' create secret docker-registry ${JS_DOCKER_REGISTRY_SECRET} \
			--docker-password="$$(cat ${JS_ENTERPRISE_CREDENTIALS_FILE})" \
			--docker-email='$(JS_DOCKER_REGISTRY_EMAIL)' \
			--docker-server='${JS_CONTAINER_REGISTRY}' \
			--docker-username='_json_key' \
			--dry-run='client' \
			--save-config=true -o yaml | kubectl apply -f -
else
	@kubectl -n 'venafi' create secret docker-registry ${JS_DOCKER_REGISTRY_SECRET} \
		--docker-password='${JS_DOCKER_REGISTRY_PASSWORD}' \
		--docker-email='${JS_DOCKER_REGISTRY_EMAIL}' \
		--docker-server='${JS_DOCKER_REGISTRY_URL}' \
		--docker-username='${JS_DOCKER_REGISTRY_USERNAME}' \
		--dry-run='client' \
		--save-config=true -o yaml | kubectl apply -f -
endif 

#STEP2. Install cert-manager. Very likely this already exists in the cluster. This install assumes approver controller is enabled.
# Enterprise cert-manager approval controller is disabled. 
install-cert-manager: 
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/cert-manager/approver-enabled.yaml \
     > artifacts/cert-manager/values.yaml
	@helm upgrade \
		--install -f artifacts/cert-manager/values.yaml cert-manager \
		--namespace venafi \
		oci://${JS_CONTAINER_REGISTRY}/charts/cert-manager \
	    --version ${JS_CERT_MANAGER_VERSION} \
		--wait

	
#STEP3. Deploy firefly. This creates a secret, config map that holds the configuration to Venafi Control Plane and deploys firefly 
install-firefly: create-sa-key _install-firefly-helm

#The service account key pair must have been created. The public key goes into Venafi control plane. The private key is stored as kubernetes secret. 
create-sa-key: 
	@kubectl create secret generic -n venafi venafi-credentials --from-file=svc-acct.key=firefly-key.pem

_install-firefly-helm:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/helm-values.yaml \
     > artifacts/firefly/values.yaml
	@helm upgrade \
		--install -f artifacts/firefly/values.yaml firefly \
		--namespace venafi \
		oci://registry.venafi.cloud/public/venafi-images/helm/firefly \
	    --version ${VENAFI_FIREFLY_VERSION} \
		--wait

#STEP4 . Create certificate.
create-certificates:
	@kubectl apply -f config/certificate.yaml

remove-certificates:
	@kubectl delete -f config/certificate.yaml || true

# All Firefly CA related API's. Use UI if that works best for you.
create-firefly-issuer:
	@echo "Creating Firefly issuer with Venafi BUILTIN CA"
	@curl --location --request POST 'https://api.venafi.cloud/v1/distributedissuers/subcaproviders' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json' \
	--data-raw \
	'{ \
		"name": "venafi-firefly-demo-ca", \
		"caType": "BUILTIN", \
		"caAccountId": "${CA_ACCOUNT_ID}", \
		"caProductOptionId": "${CA_PRODUCT_OPTION_ID}", \
		"validityPeriod": "P30D", \
		"commonName": "fireflyca.svc.cluster.local", \
		"organization": "Venafi Inc", \
		"organizationalUnit": "Jetstacker", \
		"locality": "Dallas", \
		"stateOrProvince": "TX", \
		"country": "US", \
		"keyAlgorithm": "EC_P256" \
	}'

show-firefly-issuers:
	@echo "List Firefly issuers"
	@curl --location --request GET 'https://api.venafi.cloud/v1/distributedissuers/subcaproviders' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json' \
	2>/dev/null \
	| jq '.'

show-firefly-configurations: #configurations show associated policies as well
	@echo "List Firefly configurations"
	@curl --location --request GET 'https://api.venafi.cloud/v1/distributedissuers/configurations' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json' \
	2>/dev/null \
	| jq '.'

show-firefly-policies: #policies show associated configurations as well
	@echo "List Firefly configurations"
	@curl --location --request GET 'https://api.venafi.cloud/v1/distributedissuers/policies' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json' \
	2>/dev/null \
	| jq '.'

show-firefly-intermediate-certificates: #policies show associated configurations as well
	@echo "List Firefly Issuing certificates"
	@curl --location --request GET 'https://api.venafi.cloud/v1/distributedissuers/intermediatecertificates' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json' \
	2>/dev/null \
	| jq '.'

get-firefly-intermediate-certificate-ids:
	@(curl --location --request GET 'https://api.venafi.cloud/v1/distributedissuers/intermediatecertificates' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json' \
	2>/dev/null \
	| jq '.intermediateCertificates[]|.id,.commonName')

tmp-get-firefly-intermediate-certificate-ids:
	@(curl --location --request GET 'https://api.venafi.cloud/v1/distributedissuers/intermediatecertificates' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json' \
	2>/dev/null \
	| jq '.intermediateCertificates[]|.id') > foo.sh 
	##sed -e 's/$/STRING_SUFFIX/' foo.sh
	##sed -e 's/^/STRING_PREFIX/' foo.sh

get-firefly-issuer-ids:
	@(curl --location --request GET 'https://api.venafi.cloud/v1/distributedissuers/subcaproviders' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json' \
	2>/dev/null \
	| jq '.subCaProviders[].id')

get-firefly-configuration-ids:
	@(curl --location --request GET 'https://api.venafi.cloud/v1/distributedissuers/configurations' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json' \
	2>/dev/null \
	| jq '.configurations[].id')

get-firefly-policy-ids:
	@(curl --location --request GET 'https://api.venafi.cloud/v1/distributedissuers/policies' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json' \
	2>/dev/null \
	| jq '.policies[].id')

delete-firefly-issuer:
	@echo "Delete Firefly Configuration"
	@curl --location --request DELETE 'https://api.venafi.cloud/v1/distributedissuers/configurations/ce129180-80b6-11ed-a4c5-fd2a379af263' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json'

	@curl --location --request DELETE 'https://api.venafi.cloud/v1/distributedissuers/subcaproviders/8c90b390-80b6-11ed-a4c5-fd2a379af263' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json'

delete-firefly-intermediateCertificates:
	@echo "Delete Firefly intermediate certificate"
	@curl --location --request DELETE 'https://api.venafi.cloud/v1/distributedissuers/intermediatecertificates/e0e14e00-fdc5-11ed-ba16-2b1da557b699' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json'

delete-firefly-private-key-secret:
	@kubectl delete secret venafi-credentials -n venafi || true

uninstall-firefly:
	@helm uninstall -n venafi firefly || true

uninstall-cert-manager:
	@helm uninstall -n venafi cert-manager || true

generate-key-pair:
	@openssl genrsa -out firefly-key.pem 2048
	@openssl rsa -in firefly-key.pem -pubout > firefly-key.pub
	@echo @@@@@@@ The public key contents below should be used for service account in Venafi Control Plane @@@@@@@
	@cat firefly-key.pub
	@echo @@@@@@@ The public key contents above should be used for service account in Venafi Control Plane @@@@@@@

cleanup: remove-certificates uninstall-firefly uninstall-cert-manager delete-firefly-private-key-secret
	@kubectl delete -f namespaces/sandbox.yaml || true
	@kubectl delete -f namespaces/venafi-tlspk.yaml || true


### Additional targets for using Firefly to sign mesh workloads. 

mesh-setup:
	@kubectl apply -f namespaces/istio-system.yaml
	@kubectl apply -f namespaces/mesh-apps.yaml

mesh-step1: mesh-setup
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/servicemesh/istio-csr-values.yaml \
     > artifacts/firefly/istio-csr-values.yaml

mesh-step2: _create_venafi_builtin_trust_anchor

# File is in .gitigore. Find your own trust anchor. 
_create_venafi_builtin_trust_anchor:
	@cp config/venafi-builtin-ica.pem artifacts/firefly/venafi-builtin-ica.pem
	@kubectl create secret generic ica-cert --namespace='venafi' --from-file=ica.pem=artifacts/firefly/venafi-builtin-ica.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

mesh-step3:
	@echo 'Setting up helm with the correct repos'
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo update
	@echo 'Installing Venafi istio CSR agent.....'

	@helm upgrade \
	    --install -f artifacts/firefly/istio-csr-values.yaml cert-manager-istio-csr \
  		--namespace venafi \
		oci://${JS_CONTAINER_REGISTRY}/charts/cert-manager-istio-csr \
  		--version ${JS_CERT_MANAGER_ISTIO_CSR_VERSION} \
		--wait

mesh-step4: _install-and-configure-istio

_install-and-configure-istio:
	@cp templates/servicemesh/istio-operator.yaml artifacts/firefly/istio-operator.yaml
	@istioctl install -y -f artifacts/firefly/istio-operator.yaml

mesh-step5: _create-peer-authentication
_create-peer-authentication:
	@cp templates/servicemesh/peerauthentication.yaml artifacts/firefly/peerauthentication.yaml
	@kubectl apply -f artifacts/firefly/peerauthentication.yaml

mesh-step6: _create-tlspc-public-cert-issuer _create-tlspc-public-cert
_create-tlspc-public-cert-issuer:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/tlspc/public-cert-issuer.yaml \
     > artifacts/firefly/tlspc-public-cert-issuer.yaml
	@kubectl apply -f artifacts/firefly/tlspc-public-cert-issuer.yaml
_create-tlspc-public-cert:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/tlspc/public-cert.yaml \
     > artifacts/firefly/public-cert.yaml
	@kubectl apply -f artifacts/firefly/public-cert.yaml

mesh-step7: _create_entry_in_GCP_CloudDNS
_create_entry_in_GCP_CloudDNS:
	@$(MAKE) -C ../scripts map-mesh-gateway-ip-to-dns --warn-undefined-variables

mesh-step8: _install-sample-app _create_gateway_resources
_install-sample-app:
	@kubectl -n mesh-apps apply -f https://raw.githubusercontent.com/sitaramkm/microservices-demo/main/release/kubernetes-manifests.yaml

mesh-step9: _install-istio-tools

_create_gateway_resources: HOST_DNSNAME=storefront-vtlspc.${JS_JETSTACKER_DOMAIN_NAME}
_create_gateway_resources: _create_gateway

_create_gateway:
	@cat templates/servicemesh/istio-manifests.yaml | sed -e "s/REPLACE_WITH_HOST_NAME/${HOST_DNSNAME}/g" > artifacts/firefly/istio-manifests.yaml
	@kubectl -n mesh-apps apply -f artifacts/firefly/istio-manifests.yaml
	@echo "####################################################################################################"
	@echo "######### Sample apps takes about 60 seconds before pods are Ready in mesh-apps namespace ##########"
	@echo "######### Access application using https://${HOST_DNSNAME}     ###"
	@echo "####################################################################################################"

_install-istio-tools:
	@echo 'Installing Kiali............'
	@kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${JS_ISTIO_SHORT_VERSION}/samples/addons/kiali.yaml
	@echo 'Installing Jaeger............'
	@kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${JS_ISTIO_SHORT_VERSION}/samples/addons/jaeger.yaml
	@echo 'Installing Prometheus............'
	@kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${JS_ISTIO_SHORT_VERSION}/samples/addons/prometheus.yaml
	@echo 'Installing Grafana............'
	@kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${JS_ISTIO_SHORT_VERSION}/samples/addons/grafana.yaml

print-cert:
	@$(MAKE) -C ../service-mesh/istio validate-secret --warn-undefined-variables

uninstall-istio-csr:
	@helm uninstall -n venafi cert-manager-istio-csr || true

uninstall-istio:
	@istioctl uninstall -y -f artifacts/firefly/istio-operator.yaml || true

_remove-istio-tools:
	@echo 'Removing Kiali............'
	@kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${JS_ISTIO_SHORT_VERSION}/samples/addons/kiali.yaml || true
	@echo 'Removing Jaeger............'
	@kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${JS_ISTIO_SHORT_VERSION}/samples/addons/jaeger.yaml || true
	@echo 'Removing Prometheus............'
	@kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${JS_ISTIO_SHORT_VERSION}/samples/addons/prometheus.yaml || true
	@echo 'Removing Grafana............'
	@kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${JS_ISTIO_SHORT_VERSION}/samples/addons/grafana.yaml || true

_delete-resources:
	@kubectl -n mesh-apps delete -f artifacts/firefly/istio-manifests.yaml || true
	@kubectl -n mesh-apps delete -f https://raw.githubusercontent.com/sitaramkm/microservices-demo/main/release/kubernetes-manifests.yaml || true
	@kubectl delete -f artifacts/firefly/public-cert.yaml || true
	@kubectl delete -f artifacts/firefly/tlspc-public-cert-issuer.yaml || true
	@kubectl delete -f artifacts/firefly/peerauthentication.yaml || true
	@kubectl delete secret ica-cert --namespace='venafi' || true

mesh-cleanup: _remove-istio-tools _delete-resources uninstall-istio uninstall-istio-csr 
	@kubectl delete -f namespaces/istio-system.yaml || true
	@kubectl delete -f namespaces/mesh-apps.yaml || true
	@kubectl delete MutatingWebhookConfiguration istio-revision-tag-default || true

full-cleanup: mesh-cleanup cleanup