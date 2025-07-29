#!/bin/bash

# Common Venafi Cloud variables
export CERT_SUFFIX="$(date +%S%H%M%d%m)"
export CERT_NAME="cert-${CERT_SUFFIX}.svc.cluster.local"
export VCP_TOKEN_URL="https://api.venafi.cloud/v1/oauth2/v2.0/REPLACE_WITH_YOUR_TENANT_ID/token"
export VCP_ZONE="CloudApps\\MyIssuingTemplate"
export PLATFORM="TLSPC"

# === Okta ===
export OKTA_CLIENT_ID="REPLACE_WITH_OKTA_CLIENT_ID"
export OKTA_CLIENT_SECRET="REPLACE_WITH_OKTA_CLIENT_SECRET"
export OKTA_AUTH_URL="REPLACE_WITH_OKTA_AUTH_URL"
export OKTA_SCOPE="certificates:request"

# === Azure ===
export AZURE_CLIENT_ID="REPLACE_WITH_AZURE_CLIENT_ID"
export AZURE_CLIENT_SECRET="REPLACE_WITH_AZURE_CLIENT_SECRET"
export AZURE_AUTH_URL="https://login.microsoftonline.com/REPLACE_WITH_TENANT_ID"
export AZURE_SCOPE="REPLACE_WITH_SCOPE"

# === Auth0 ===
export AUTH0_CLIENT_ID="REPLACE_WITH_AUTH0_CLIENT_ID"
export AUTH0_CLIENT_SECRET="REPLACE_WITH_AUTH0_CLIENT_SECRET"
export AUTH0_AUTH_URL="REPLACE_WITH_AUTH0_AUTH_URL"
export AUTH0_SCOPE="certificates:request"
export AUTH0_AUDIENCE="REPLACE_WITH_AUTH0_AUDIENCE"
