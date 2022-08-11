#!/usr/bin/env bash

PROJECT_ID=${1}
REGION=${2}
DNS_NAME=${3}
CERTIFICATE_AUTHORITY_NAME=${4}
CERTIFICATE_AUTHORITY_POOL_NAME=${5}
TIER=${6}

echo "Checking if private CA pool exists"
if ! gcloud privateca pools describe ${CERTIFICATE_AUTHORITY_POOL_NAME} --location ${REGION} > /dev/null 2>&1; then
  echo "Create private CA pool"
  gcloud privateca pools create ${CERTIFICATE_AUTHORITY_POOL_NAME} --tier=${TIER} --location ${REGION}
else
  echo "Private CA Pool exists"
fi

echo "Checking if private CA exists"
if ! gcloud privateca roots describe ${CERTIFICATE_AUTHORITY_NAME} --pool ${CERTIFICATE_AUTHORITY_POOL_NAME} --location ${REGION} > /dev/null 2>&1; then
  echo "Creating private CA"
  gcloud privateca roots create ${CERTIFICATE_AUTHORITY_NAME} --pool ${CERTIFICATE_AUTHORITY_POOL_NAME} --auto-enable --subject "CN=${DNS_NAME}, O=Jetstack" --max-chain-length=2 --location ${REGION} 
else
  echo "Private CA already exists"
fi

echo "Checking if service accounts exists"
if ! gcloud iam service-accounts describe google-cas-issuer@${PROJECT_ID}.iam.gserviceaccount.com  > /dev/null 2>&1; then
  echo "Creating service account"
  gcloud iam service-accounts create google-cas-issuer
else
  echo "Service account already exists"
fi

echo "Checking if private CA IAM binding exists"
if ! gcloud privateca pools get-iam-policy ${CERTIFICATE_AUTHORITY_POOL_NAME} --location ${REGION} | grep serviceAccount:google-cas-issuer@${PROJECT_ID}.iam.gserviceaccount.com  > /dev/null 2>&1; then
  echo "Creating private CA IAM binding"
  gcloud privateca pools add-iam-policy-binding ${CERTIFICATE_AUTHORITY_POOL_NAME} --location ${REGION} --role=roles/privateca.certificateRequester --member="serviceAccount:google-cas-issuer@${PROJECT_ID}.iam.gserviceaccount.com"
else
  echo "Private CA IAM binding already exists"
fi

echo "Checking if IAM binding exists"
if ! gcloud iam service-accounts get-iam-policy google-cas-issuer@${PROJECT_ID}.iam.gserviceaccount.com | grep ${PROJECT_ID}.svc.id.goog | grep ksa-google-cas-issuer > /dev/null 2>&1; then
  echo "Creating IAM binding"
  gcloud iam service-accounts add-iam-policy-binding --role roles/iam.workloadIdentityUser --member "serviceAccount:${PROJECT_ID}.svc.id.goog[cert-manager/ksa-google-cas-issuer]" google-cas-issuer@${PROJECT_ID}.iam.gserviceaccount.com
else
  echo "IAM binding already exists"
fi
