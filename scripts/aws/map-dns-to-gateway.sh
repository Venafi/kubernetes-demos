#!/usr/bin/env bash
ZONE=$1
DNS_NAME=$2
PROFILE=$3

echo "Zone is ${ZONE}"
echo "DNS is ${DNS_NAME}"
echo "Using AWS Profile ${PROFILE}"

# Get the Istio Ingress Gateway IP address
INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Get the Istio Ingress Gateway hostname (if available)
INGRESS_HOSTNAME=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -n "$INGRESS_HOSTNAME" ]; then
  echo "Istio Ingress Hostname: $INGRESS_HOSTNAME"
  aws --profile ${PROFILE} route53 change-resource-record-sets \
      --hosted-zone-id ${ZONE} \
      --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"'${DNS_NAME}.'","Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":"'${INGRESS_HOSTNAME}'"}]}}]}'    
elif [ -n "$INGRESS_IP" ]; then
  echo "Istio Ingress IP: $INGRESS_IP"
  aws --profile ${PROFILE} route53 change-resource-record-sets \
      --hosted-zone-id ${ZONE} \
      --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"'${DNS_NAME}.'","Type":"A","TTL":300,"ResourceRecords":[{"Value":"'${INGRESS_IP}'"}]}}]}'    
else
  echo "Couldn't figure out hostname or IP from ingress gateway service. NO CHANGES made to DNS records"
fi
