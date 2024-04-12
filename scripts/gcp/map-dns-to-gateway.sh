#!/usr/bin/env bash
ZONE=$1
DNS_NAME=$2

dns=$(gcloud dns record-sets list --zone="${ZONE}")

echo "Creating DNS records"
gcloud dns record-sets transaction start --zone=${ZONE}

if [[ $(echo ${dns} | grep "${DNS_NAME}") ]]; then
    gcloud dns record-sets transaction remove --zone=${ZONE} --name="${DNS_NAME}" --ttl 60  --type A $(dig +short ${DNS_NAME})
fi

gcloud dns record-sets transaction add --zone=${ZONE} --name="${DNS_NAME}" --ttl 60 --type A $(kubectl get services --namespace istio-system istio-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
gcloud dns record-sets transaction execute --zone ${ZONE}
echo "DNS records created"

#gcloud dns record-sets transaction add --zone=${ZONE} --name="${DNS_NAME}" --ttl 60 --type="CNAME" --rrdatas="$(kubectl get services --namespace istio-system istio-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')"