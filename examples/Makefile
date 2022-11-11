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

	@kubectl apply -f namespaces/sample-apps.yaml

########################################################################################################################
# Ingress
########################################################################################################################

install-sample-app:
	@kubectl apply -f apps/sample-app.yaml

create-venafi-issuer:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < ingress/templates/venafi-issuer.yaml \
     > artifacts//ingress/venafi-issuer.yaml
	kubectl apply -f artifacts/ingress/venafi-issuer.yaml

create-sample-apps-policy:
	@kubectl apply -f ingress/cert-policy-for-sample-apps.yaml

create-certificate-for-ingress:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < ingress/templates/sample-cert.yaml \
     > artifacts//ingress/sample-cert.yaml
	@kubectl apply -f artifacts/ingress/sample-cert.yaml

create-ingress-resource:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < ingress/templates/sample-ingress.yaml \
     > artifacts//ingress/sample-ingress.yaml
	@kubectl apply -f artifacts/ingress/sample-ingress.yaml	

create-openshift-ingress-resource:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < openshift/ingress/templates/openshift-sample-ingress.yaml \
     > artifacts//ingress/openshift-sample-ingress.yaml
	@kubectl apply -f artifacts/ingress/openshift-sample-ingress.yaml

install-cert-manager-openshift-route:
	@kubectl apply -f namespaces/cert-manager.yaml
	@kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.yaml

create-openshift-route-policy:
	@kubectl apply -f openshift/routes/cert-policy-for-openshift-route.yaml

create-openshift-route-resource:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < openshift/routes/templates/openshift-sample-route.yaml \
     > artifacts//ingress/openshift-sample-route.yaml
	@kubectl apply -f artifacts/ingress/openshift-sample-route.yaml

rmdirs:
	@rm -rf artifacts
	@rm -rf truststores

delete-namespaces:
	@kubectl delete -f namespaces/sample-apps.yaml || true

uninstall-sample-app:
	@kubectl delete -f apps/sample-app.yaml || true

remove-venafi-issuer:
	kubectl delete -f artifacts/ingress/venafi-issuer.yaml || true

remove-sample-apps-policy:
	@kubectl delete -f ingress/cert-policy-for-sample-apps.yaml || true

remove-certificate-for-ingress:
	@kubectl delete -f artifacts/ingress/sample-cert.yaml || true

remove-ingress-resource:
	@kubectl delete -f artifacts/ingress/sample-ingress.yaml || true

remove-openshift-ingress-resource:
	@kubectl delete -f artifacts/ingress/openshift-sample-ingress.yaml || true

remove-openshift-route-policy:
	@kubectl delete -f openshift/routes/cert-policy-for-openshift-route.yaml || true

remove-openshift-route-resource:
	@kubectl delete -f artifacts/ingress/openshift-sample-route.yaml || true

uninstall-cert-manager-openshift-route:
	@kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.yaml || true

clean-route: remove-openshift-route-resource remove-openshift-route-policy remove-venafi-issuer uninstall-sample-app uninstall-cert-manager-openshift-route

clean-ingress: remove-openshift-ingress-resource remove-ingress-resource remove-certificate-for-ingress remove-sample-apps-policy remove-venafi-issuer uninstall-sample-app 


########################################################################################################################
# Trust Stores 
########################################################################################################################

create-venafi-issuer-truststore:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < truststores/templates/venafi-issuer.yaml \
     > artifacts//truststores/venafi-issuer.yaml
	kubectl apply -f artifacts/truststores/venafi-issuer.yaml

create-truststore-password:
	@kubectl create secret generic jks-password-secret --from-literal=password-key=changeit -n sample-apps

create-trustsore-policy:
	@kubectl apply -f truststores/templates/cert-policy-for-truststores.yaml

create-server-certificate:
	@kubectl apply -f truststores/templates/sample-server-cert.yaml

create-client-certificate:
	@kubectl apply -f truststores/templates/sample-client-cert.yaml

deploy-app-for-truststores:
	@kubectl apply -f apps/sample-truststore-client-app.yaml

## TEST APP USING CURL
test-trust-app-fail:
	@curl https://<Loadbalancer IP>/trust

test-trust-app:
	@kubectl get secret java-client-truststore -n sandbox  -o json | jq -r '.data."tls.crt"'| base64 -d > artifacts/truststores/tls.crt
	@kubectl get secret java-client-truststore -n sandbox  -o json | jq -r '.data."tls.key"'| base64 -d > artifacts/truststores/tls.key
	@kubectl get secret java-client-truststore -n sandbox  -o json | jq -r '.data."ca.crt"'| base64 -d > artifacts/truststores/ca.crt
	@curl https://<Loadbalancer IP>/trust --cert artifacts/truststores/tls.crt --key artifacts/truststores/tls.key --cacert artifacts/truststores/ca.crt -k


remove-trustsore-policy:
	@kubectl delete -f truststores/templates/cert-policy-for-truststores.yaml || true

remove-truststores-certificates:
	@kubectl delete -f truststores/templates/sample-server-cert.yaml || true
	@kubectl delete -f truststores/templates/sample-client-cert.yaml || true


remove-truststores-issuer:
	@kubectl delete -f artifacts/ingress/venafi-issuer.yaml || true

delete-truststore-password:
	@kubectl delete secret generic jks-password-secret -n sandbox

remove-app-for-truststores:
	@kubectl delete -f artifacts/truststores/sample-app.yaml || true
	

clean-truststores: remove-app-for-truststores remove-trustsore-policy remove-truststores-certificates delete-truststore-password remove-truststores-certificates remove-truststores-issuer 

