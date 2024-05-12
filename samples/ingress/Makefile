MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.PHONY: help clean check_clean
SHELL := /bin/sh

 # Include personal settings
 include ../../main/vars.sh

mkdirs:
	@rm -rf artifacts
	@mkdir -p artifacts/samples/ingress

################## PREP KUBERNETES CLUSTER FOR ISOLATED ISSUER #################
init: mkdirs 

install-nginx-ingress-controller:
	@helm upgrade --install ingress-nginx ingress-nginx \
  				  --repo https://kubernetes.github.io/ingress-nginx \
  				  --namespace ingress-nginx \
				  --create-namespace

create-ingress:
	@cp templates/sample-ingress.yaml artifacts/samples/ingress/sample-ingress.yaml 
	@kubectl apply -f artifacts/samples/ingress/sample-ingress.yaml 

uninstall-nginx-ingress-controller:
	@helm uninstall ingress-nginx -n ingress-nginx || true

remove-ingress:
	@kubectl delete -f artifacts/samples/ingress/sample-ingress.yaml || true
	
clean: remove-ingress uninstall-nginx-ingress-controller