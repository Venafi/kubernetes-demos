MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean
SHELL := /bin/sh

 # Include personal settings
 include ../settings.sh


########################################################################################################################
#  Review each command in the targets. 
########################################################################################################################

init: mkdirs create-namespaces

mkdirs:
	@rm -rf artifacts
	@mkdir -p artifacts/ingress
	@mkdir -p artifacts/truststores

create-namespaces:

	@kubectl apply -f namespaces/sandbox.yaml


########################################################################################################################
# Ingress  & ROUTES
########################################################################################################################

create-venafi-issuer-ingress:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < ingress/templates/venafi-issuer.yaml \
     > artifacts//ingress/venafi-issuer.yaml
	kubectl apply -f artifacts//ingress/venafi-issuer.yaml

_create-config-map-with-PEM-to-access-TPP:
	@cp ${JS_VENAFI_TPP_CA_BUNDLE_PEM_FILE} artifacts/ingress/venafi-server-ca.pem
	@kubectl create configmap venafi-tpp-ca-bundle --namespace='jetstack-secure' --from-file=ca.crt=artifacts/ingress/venafi-server-ca.pem --dry-run=client --save-config=true -o yaml | kubectl apply -f -

_create-tpp-access-secret-for-policy:
	@kubectl create secret generic access-token --namespace='jetstack-secure' --from-literal=access-token='${JS_VENAFI_TPP_ACCESS_TOKEN}' --dry-run=client --save-config=true -o yaml | kubectl apply -f -

create-venafi-tpp-ingress-certificate-policy: _create-config-map-with-PEM-to-access-TPP _create-tpp-access-secret-for-policy
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < ingress/templates/cert-policy.yaml \
     > artifacts/ingress/cert-policy.yaml
	@kubectl apply -f artifacts/ingress/cert-policy.yaml
	@kubectl apply -f ingress/templates/cert-policy-rbac.yaml

deploy-app-for-ingress:
	@kubectl apply -f ingress/templates/sample-app.yaml

create-ingress-certificate:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < ingress/templates/sample-cert.yaml \
     > artifacts/ingress/sample-cert.yaml
	@kubectl apply -f artifacts/ingress/sample-cert.yaml

create-ingress:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < ingress/templates/sample-ingress.yaml \
     > artifacts/ingress/sample-ingress.yaml
	@kubectl apply -f artifacts/ingress/sample-ingress.yaml

create-certmanager-oc-resource:
	@kubectl apply -f https://github.com/cert-manager/openshift-routes/releases/latest/download/cert-manager-openshift-routes.yaml -n cert-manager

create-route:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < ingress/templates/sample-route.yaml \
     > artifacts/ingress/sample-route.yaml
	@kubectl apply -f artifacts/ingress/sample-route.yaml

remove-ingress:
	@kubectl delete -f artifacts/ingress/sample-ingress.yaml || true

remove-ingress-app:
	@kubectl delete -f artifacts/ingress/sample-app.yaml || true

remove-route:
	@kubectl delete -f artifacts/ingress/sample-route.yaml || true

remove-ingress-certificates:
	@kubectl delete -f artifacts/ingress/sample-cert.yaml || true

remove-ingress-issuer:
	@kubectl delete -f artifacts/ingress/venafi-issuer.yaml || true

remove-ingress-rbac:
	@kubectl delete -f ingress/templates/cert-policy-rbac.yaml || true

remove-ingress-cert-policy:
	@kubectl delete -f artifacts/cert-approver/venafi/cert-policy.yaml || true

clean-ingress: remove-ingress-app remove-ingress-certificates remove-ingress-issuer remove-ingress-rbac remove-ingress-cert-policy remove-ingress remove-route

########################################################################################################################
# Trust Stores 
########################################################################################################################

create-venafi-issuer-truststore:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < truststores/templates/venafi-issuer.yaml \
     > artifacts//truststores/venafi-issuer.yaml
	kubectl apply -f artifacts/truststores/venafi-issuer.yaml

create-venafi-tpp-trust-certificate-policy: _create-config-map-with-PEM-to-access-TPP _create-tpp-access-secret-for-policy
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < truststores/templates/cert-policy.yaml \
     > artifacts/truststores/cert-policy.yaml
	@kubectl apply -f artifacts/truststores/cert-policy.yaml
	@kubectl apply -f truststores/templates/cert-policy-rbac.yaml

create-truststore-password:
	@kubectl create secret generic jks-password-secret --from-literal=password-key=changeit -n sandbox

create-server-certificate:
	@kubectl apply -f truststores/templates/sample-server-cert.yaml

create-client-certificate:
	@kubectl apply -f truststores/templates/sample-client-cert.yaml

deploy-app-for-truststores:
	@kubectl apply -f truststores/templates/sample-app.yaml

## TEST APP USING CURL
test-trust-app-fail:
	@curl https://<Loadbalancer IP>/trust

test-trust-app:
	@kubectl get secret java-client-truststore -n sandbox  -o json | jq -r '.data."tls.crt"'| base64 -d > artifacts/truststores/tls.crt
	@kubectl get secret java-client-truststore -n sandbox  -o json | jq -r '.data."tls.key"'| base64 -d > artifacts/truststores/tls.key
	@kubectl get secret java-client-truststore -n sandbox  -o json | jq -r '.data."ca.crt"'| base64 -d > artifacts/truststores/ca.crt
	@curl https://<Loadbalancer IP>/trust --cert artifacts/truststores/tls.crt --key artifacts/truststores/tls.key --cacert artifacts/truststores/ca.crt -k


remove-truststores-cert-policy:
	@kubectl delete -f artifacts/truststores/cert-policy.yaml || true

remove-truststores-rbac:
	@kubectl delete -f artifacts/truststores/cert-policy-rbac.yaml || true

remove-truststores-certificates:
	@kubectl delete -f truststores/templates/sample-server-cert.yaml || true
	@kubectl delete -f truststores/templates/sample-client-cert.yaml || true


remove-truststores-issuer:
	@kubectl delete -f artifacts/ingress/venafi-issuer.yaml || true

delete-truststore-password:
	@kubectl delete secret generic jks-password-secret -n sandbox

remove-app-for-truststores:
	@kubectl delete -f artifacts/truststores/sample-app.yaml || true

clean-truststores: remove-app-for-truststores remove-truststores-rbac remove-truststores-cert-policy delete-truststore-password remove-truststores-certificates remove-truststores-issuer 