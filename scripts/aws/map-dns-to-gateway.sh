#!/usr/bin/env bash
ZONE=$1
DNS_NAME=$2

echo "Zone is ${ZONE}"
echo "DNS is ${DNS_NAME}"

#recordvalue="$(kubectl get services --namespace istio-system istio-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
recordvalue="$(kubectl get services --namespace istio-system istio-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')"

aws --profile basic route53 change-resource-record-sets \
  --hosted-zone-id ${ZONE} \
  --change-batch '{"Changes":[{"Action":"CREATE","ResourceRecordSet":{"Name":"'${DNS_NAME}.'","Type":"A","TTL":300,"ResourceRecords":[{"Value":"'${recordvalue}'"}]}}]}'  