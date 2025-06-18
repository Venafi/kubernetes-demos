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
	@mkdir -p artifacts/samples/csi-driver

################## PREP KUBERNETES CLUSTER FOR ISOLATED ISSUER #################
init: mkdirs 

_create_policy_for_redis_pod_identities: 
	@envsubst "$$(printf '$${%s} ' $${!VEN_*})" < templates/redis-certs-policy-and-rbac.yaml \
     > artifacts/samples/csi-driver/redis-certs-policy-and-rbac.yaml
	@kubectl apply -f artifacts/samples/csi-driver/redis-certs-policy-and-rbac.yaml

deploy-redis-app: _create_policy_for_redis_pod_identities
	@cp templates/redis-server.yaml artifacts/samples/csi-driver/redis-server.yaml
	@cp templates/redis-client.yaml artifacts/samples/csi-driver/redis-client.yaml
	@kubectl apply -f artifacts/samples/csi-driver/redis-server.yaml
	@kubectl apply -f artifacts/samples/csi-driver/redis-client.yaml

_remove_policy_for_redis_pod_identities:
	@kubectl delete -f artifacts/samples/csi-driver/redis-certs-policy-and-rbac.yaml || true

remove-redis-app: _remove_policy_for_redis_pod_identities
	@kubectl delete -f artifacts/samples/csi-driver/redis-server.yaml || true
	@kubectl delete -f artifacts/samples/csi-driver/redis-client.yaml || true

clean: remove-redis-app remove-policy-and-rbac 