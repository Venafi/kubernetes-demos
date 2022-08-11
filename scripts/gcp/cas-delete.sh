#!/usr/bin/env bash

PROJECT_ID=${1}
REGION=${2}
DNS_NAME=${3}
CERTIFICATE_AUTHORITY_NAME=${4}
CERTIFICATE_AUTHORITY_POOL_NAME=${5}

gcloud iam service-accounts remove-iam-policy-binding --role roles/iam.workloadIdentityUser --member "serviceAccount:${PROJECT_ID}.svc.id.goog[cert-manager/ksa-google-cas-issuer]" google-cas-issuer@${PROJECT_ID}.iam.gserviceaccount.com
gcloud privateca pools remove-iam-policy-binding ${CERTIFICATE_AUTHORITY_POOL_NAME} --location ${REGION} --role=roles/privateca.certificateRequester --member="serviceAccount:google-cas-issuer@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud iam service-accounts delete google-cas-issuer@${PROJECT_ID}.iam.gserviceaccount.com --quiet
gcloud privateca roots disable ${CERTIFICATE_AUTHORITY_NAME} --pool ${CERTIFICATE_AUTHORITY_POOL_NAME} --location ${REGION} --quiet

PROJECT_NUMBER="$(gcloud projects list --filter="${PROJECT_ID}" --format="value(PROJECT_NUMBER)")"
CERTS_TO_REVOKE="$(gcloud privateca certificates list --issuer-pool=${CERTIFICATE_AUTHORITY_POOL_NAME} \
            --location=${REGION} \
            --filter="issuer_certificate_authority='projects/${PROJECT_NUMBER}/locations/${REGION}/caPools/${CERTIFICATE_AUTHORITY_POOL_NAME}/certificateAuthorities/${CERTIFICATE_AUTHORITY_NAME}'" \
            --format="table(name, revocation_details)" | cut -d " " -f1)"

for CERT in $CERTS_TO_REVOKE; do
  gcloud privateca certificates revoke --certificate "$CERT" \
  --issuer-pool ${CERTIFICATE_AUTHORITY_POOL_NAME} \
  --quiet --issuer-location ${REGION} || true
done

gcloud privateca roots delete ${CERTIFICATE_AUTHORITY_NAME} --pool ${CERTIFICATE_AUTHORITY_POOL_NAME} --location ${REGION} --quiet
#root delete really removed after 30 days. Pool cannot be removed unless all roots are removed. even with quiet it fails. 
# Attempt to remove the pool will fail very likely considering there will be at least one CA that's not completely gone. 
gcloud privateca pools delete ${CERTIFICATE_AUTHORITY_POOL_NAME} --location ${REGION} --quiet || true

#To recover a delete CA run
# gcloud beta privateca roots undelete jetstack-secure-demo-01 \
#       --pool jss-demo-pool \
#       --location us-central1

