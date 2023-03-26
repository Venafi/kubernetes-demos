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
	@mkdir -p artifacts/firefly-ca
	@mkdir -p artifacts/cert-manager

make-namespaces:
	@kubectl apply -f namespaces/sandbox.yaml
	@kubectl apply -f namespaces/venafi-tlspk.yaml

configure-namespace:
ifneq (${JS_AIRGAPPED},true)
	@echo "Creating docker registry secret. You must have the credentials file to create a secret"
	@echo
	@kubectl -n 'cert-manager' create secret docker-registry ${JS_DOCKER_REGISTRY_SECRET} \
			--docker-password="$$(cat ${JS_ENTERPRISE_CREDENTIALS_FILE})" \
			--docker-email='$(JS_DOCKER_REGISTRY_EMAIL)' \
			--docker-server='${JS_CONTAINER_REGISTRY}' \
			--docker-username='_json_key' \
			--dry-run='client' \
			--save-config=true -o yaml | kubectl apply -f -
else
	@kubectl -n 'cert-manager' create secret docker-registry ${JS_DOCKER_REGISTRY_SECRET} \
		--docker-password='${JS_DOCKER_REGISTRY_PASSWORD}' \
		--docker-email='${JS_DOCKER_REGISTRY_EMAIL}' \
		--docker-server='${JS_DOCKER_REGISTRY_URL}' \
		--docker-username='${JS_DOCKER_REGISTRY_USERNAME}' \
		--dry-run='client' \
		--save-config=true -o yaml | kubectl apply -f -
endif 

#STEP2. Create the kubeconfig required for fireflyCA to run. This is temporary and will go away. 
create-kubeconfig:
	@echo "Create kubeconfig. Run the shell script like this... "
	@echo "Replace CLUSTER_FULLNAME with your cluster name and CLUSTER_URL with your cluster URL. Example below"
	@echo
	@echo "CLUSTER_FULLNAME=arn:aws:eks:<your-region>:<your-account>:cluster/<your-cluster-name> CLUSTER_URL=https://<whatever-you-see-in-the-url>.eks.amazonaws.com ./create-kube-config.sh"
	@echo
	@echo "The Service account associcated kubeconfig is generated - written to console as well as to file artifacts/kubeconfig.yaml"

#STEP3. Install cert-manager. Very likely this already exists in the cluster. This install assumes approver controller is enabled.
# Enterprise cert-manager approval controller is disabled. 
install-cert-manager: 
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < cert-manager/values.yaml \
     > artifacts/cert-manager/values.yaml
	@helm upgrade \
		--install -f artifacts/cert-manager/values.yaml cert-manager \
		--namespace cert-manager \
		oci://${JS_CONTAINER_REGISTRY}/charts/cert-manager \
	    --version ${JS_CERT_MANAGER_VERSION} \
		--wait

#create-firefly-crds:
#	@kubectl apply -f config/cert-manager-fireflyca-crd.yaml
#	@kubectl apply -f config/cert-manager-fireflyca-rbac.yaml

#STEP4. Deploy fireflyCA. This creates a config map that holds the configuration to Venafi Control Plane and also holds the kubeconfig generated for the 
#service account 'firefly-ca' that has the permission to control the deployment. 
deploy-firefly: create-firefly-configmap install-firefly

create-firefly-configmap:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < config/firefly-config.yaml \
     > artifacts/firefly-ca/config1.yaml
	 @cat artifacts/firefly-ca/config1.yaml | sed -e "s/REPLACE_WITH_TIMESTAMP/$(shell date +%Y-%m-%d-%H%M)/g" > artifacts/firefly-ca/config.yaml
	 @rm -rf artifacts/firefly-ca/config1.yaml
	@kubectl create configmap -n cert-manager firefly-ca-config --from-file artifacts/firefly-ca/config.yaml --from-file artifacts/kubeconfig.yaml

# Installation is done via static manifests at this time. These manifests are generated via a Helm Chart and will be changed
# to do a direct Helm install once published to OCI 
install-firefly:
	@kubectl -n cert-manager apply -f config/firefly-resources.yaml

#STEP5 . Create certificate.
create-certificates:
	@kubectl apply -f config/certificate.yaml

remove-certificates:
	@kubectl delete -f config/certificate.yaml || true


# All Firefly CA related API's. Use UI if that works best for you.

create-firefly-ca-issuer:
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

show-firefly-ca-issuers:
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

get-firefly-ca-issuer-ids:
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

delete-firefly-ca-issuer:
	@echo "Delete Firefly Configuration"
	@curl --location --request DELETE 'https://api.venafi.cloud/v1/distributedissuers/configurations/ce129180-80b6-11ed-a4c5-fd2a379af263' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json'

	@curl --location --request DELETE 'https://api.venafi.cloud/v1/distributedissuers/subcaproviders/8c90b390-80b6-11ed-a4c5-fd2a379af263' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json'

delete-firefly-intermediateCertificates:
	@echo "Delete Firefly intermediate certificate"
	@curl --location --request DELETE 'https://api.venafi.cloud/v1/distributedissuers/intermediatecertificates/ae45b480-cb1c-11ed-8c19-05231112a342' \
	--header 'tppl-api-key: ${JS_VENAFI_CLOUD_API_KEY}' \
	--header 'Content-Type: application/json'

#delete-firefly-crds:
# @kubectl delete -f config/cert-manager-fireflyca-crd.yaml || true
#	#@kubectl delete -f config/cert-manager-fireflyca-rbac.yaml || true

uninstall-firfly-ca:
	@kubectl -n cert-manager delete -f config/firefly-resources.yaml || true
	@kubectl -n cert-manager delete configmap firefly-ca-config || true

uninstall-cert-manager:
	@helm uninstall -n cert-manager cert-manager || true

cleanup: remove-certificates uninstall-firfly-ca uninstall-cert-manager
	@kubectl delete -f namespaces/sandbox.yaml || true
	@kubectl delete -f namespaces/venafi-tlspk.yaml || true
