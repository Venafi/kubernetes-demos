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

install-sample-app:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/apps/sample-app.yaml \
     > artifacts/ingress/sample-app.yaml
	@kubectl apply -f artifacts/ingress/sample-app.yaml


create-venafi-connection-rbac:
	@$(MAKE) -C  ../common create-venafi-connection-rbac --warn-undefined-variables

create-venafi-tpp-connection:
	@$(MAKE) -C ../common create-venafi-tpp-connection --warn-undefined-variables

create-venafi-issuer:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/venafi-issuer.yaml \
     > artifacts/venafi-issuer.yaml
	@kubectl apply -f artifacts/venafi-issuer.yaml

########################################################################################################################
# Ingress
########################################################################################################################


create-sample-apps-policy:
	@kubectl apply -f templates/ingress/cert-policy-for-sample-apps.yaml

create-certificate-for-ingress:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/sample-cert.yaml \
     > artifacts/sample-cert.yaml
	@kubectl apply -f artifacts/sample-cert.yaml

create-ingress-resource:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/ingress/sample-ingress.yaml \
     > artifacts/ingress/sample-ingress.yaml
	@kubectl apply -f artifacts/ingress/sample-ingress.yaml	


################################################# OPEN SHIFT INGRESS #######################################################################
install-openshift-route:
	@$(MAKE) -C cert-manager-opnshift-routes install-cert-manager-openshift-route --warn-undefined-variables

create-openshift-route-policy:
	@kubectl apply -f templates/openshift/cert-policy-for-openshift-route.yaml

create-openshift-ingress-resource:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/openshift/openshift-sample-ingress.yaml \
     > artifacts/ingress/openshift-sample-ingress.yaml
	@kubectl apply -f artifacts/ingress/openshift-sample-ingress.yaml

create-openshift-route-resource:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/openshift/openshift-sample-route.yaml \
     > artifacts/ingress/openshift-sample-route.yaml
	@kubectl apply -f artifacts/ingress/openshift-sample-route.yaml


################################################# Clean Up#######################################################################
rmdirs:
	@rm -rf artifacts
	@rm -rf truststores

delete-namespaces:
	@kubectl delete -f namespaces/sandbox.yaml || true

uninstall-sample-app:
	@kubectl delete -f apps/sample-app.yaml || true

################################################# Clean Ingress#######################################################################

remove-sample-apps-policy:
	@kubectl delete -f templates/ingress/cert-policy-for-sample-apps.yaml || true

remove-certificate-for-ingress:
	@kubectl delete  -f artifacts/sample-cert.yaml || true

remove-ingress-resource:
	@kubectl delete -f artifacts/ingress/sample-ingress.yaml || true

################################################# Clean Route#######################################################################


remove-openshift-ingress-resource:
	@kubectl delete -f artifacts/ingress/openshift-sample-ingress.yaml || true

remove-openshift-route-policy:
	@kubectl delete -f templates/openshift/cert-policy-for-openshift-route.yaml || true

remove-openshift-route-resource:
	@kubectl delete -f artifacts/ingress/openshift-sample-route.yaml || true

################################################# Cleanup all#######################################################################

clean-route: remove-openshift-route-resource remove-openshift-route-policy 

clean-ingress: remove-openshift-ingress-resource remove-ingress-resource remove-certificate-for-ingress remove-sample-apps-policy 

########################################################################################################################
# Trust Stores 
########################################################################################################################
create-venafi-issuer-for-trustsore:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/truststores/venafi-issuer-ts.yaml \
     > artifacts/truststores/venafi-issuer-ts.yaml
	@kubectl apply -f artifacts/truststores/venafi-issuer-ts.yaml

create-truststore-password:
	@kubectl create secret generic jks-password-secret --from-literal=password-key=changeit -n sandbox

create-trustsore-policy:
	@kubectl apply -f templates/truststores/cert-policy-for-truststores.yaml

create-server-certificate:
	@kubectl apply -f templates/truststores/sample-server-cert.yaml

create-client-certificate:
	@kubectl apply -f templates/truststores/sample-client-cert.yaml

deploy-app-for-truststores:
	@envsubst "$$(printf '$${%s} ' $${!JS_*})" < templates/apps/sample-truststore-app.yaml \
     > artifacts/trustsores/sample-truststore-app.yaml
	@kubectl apply -f artifacts/trustsores/sample-truststore-app.yaml

## TEST APP USING CURL
test-trust-app-fail:
	@curl https://<Loadbalancer IP>/trust

test-trust-app:
	@kubectl get secret java-client-truststore -n sandbox  -o json | jq -r '.data."tls.crt"'| base64 -d > artifacts/truststores/tls.crt
	@kubectl get secret java-client-truststore -n sandbox  -o json | jq -r '.data."tls.key"'| base64 -d > artifacts/truststores/tls.key
	@kubectl get secret java-client-truststore -n sandbox  -o json | jq -r '.data."ca.crt"'| base64 -d > artifacts/truststores/ca.crt
	@curl https://<Loadbalancer IP>/trust --cert artifacts/truststores/tls.crt --key artifacts/truststores/tls.key --cacert artifacts/truststores/ca.crt -k


remove-trustsore-policy:
	@kubectl delete -f templates/truststores/cert-policy-for-truststores.yaml || true

remove-truststores-certificates:
	@kubectl delete -f templates/truststores/sample-server-cert.yaml || true
	@kubectl delete -f templates/truststores/sample-client-cert.yaml || true


delete-truststore-password:
	@kubectl delete secret generic jks-password-secret -n sandbox || true

remove-app-for-truststores:
	@kubectl delete -f artifacts/trustsores/sample-truststore-app.yaml || true
	

remove-venafi-connection:
	@$(MAKE) -C ../common clean --warn-undefined-variables || true

remove-venafi-issuer:
	@kubectl delete -f artifacts/venafi-issuer.yaml || true

clean-truststores: remove-app-for-truststores remove-trustsore-policy remove-truststores-certificates delete-truststore-password remove-truststores-certificates 

clean-examples: remove-venafi-issuer remove-venafi-tpp-connection remove-venafi-connection-rbac remove-venafi-credentials clean-truststores clean-ingress clean-route



