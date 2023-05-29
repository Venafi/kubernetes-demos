#!/usr/bin/env bash
ZONE=$1
DNS_NAME=$2

dns=$(gcloud dns record-sets list --zone="${ZONE}")

echo "Creating DNS records"
gcloud dns record-sets transaction start --zone=${ZONE}

if [[ $(echo ${dns} | grep "storefront-vtpp.${DNS_NAME}") ]]; then
    gcloud dns record-sets transaction remove --zone=${ZONE} --name="storefront-vtpp.${DNS_NAME}" --ttl 60  --type A $(dig +short storefront-vtpp.${DNS_NAME})
fi

if [[ $(echo ${dns} | grep "storefront-vtlspc.${DNS_NAME}") ]]; then
    gcloud dns record-sets transaction remove --zone=${ZONE} --name="storefront-vtlspc.${DNS_NAME}" --ttl 60  --type A $(dig +short storefront-vtlspc.${DNS_NAME})
fi

if [[ $(echo ${dns} | grep "sayhello.${DNS_NAME}") ]]; then
    gcloud dns record-sets transaction remove --zone=${ZONE} --name="sayhello.${DNS_NAME}" --ttl 60  --type A $(dig +short sayhello.${DNS_NAME})
fi

gcloud dns record-sets transaction add --zone=${ZONE} --name="storefront-vtlspc.${DNS_NAME}" --ttl 60 --type A $(kubectl get services --namespace istio-system istio-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
gcloud dns record-sets transaction add --zone=${ZONE} --name="storefront-vtpp.${DNS_NAME}" --ttl 60 --type A $(kubectl get services --namespace istio-system istio-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
gcloud dns record-sets transaction add --zone=${ZONE} --name="sayhello.${DNS_NAME}" --ttl 60 --type A $(kubectl get services --namespace istio-system istio-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
gcloud dns record-sets transaction execute --zone ${ZONE}
echo "DNS records created"

