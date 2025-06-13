#!/bin/bash

set -euo pipefail

echo "[setup] Preparing environment..."

# Validate required variables
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR not set}"
: "${RESOURCE_SUFFIX:?RESOURCE_SUFFIX not set}"
: "${CYBR_CLOUD_API_KEY:?CYBR_CLOUD_API_KEY not set}"
: "${CLOUD_URL:?CLOUD_URL not set}"

# Recreate artifact directories safely
if [ -d "${ARTIFACTS_DIR}" ]; then
  echo "[setup] Warning: ${ARTIFACTS_DIR} already exists. Deleting..."
  rm -rf "${ARTIFACTS_DIR}"
fi

mkdir -pv "${ARTIFACTS_DIR}"/{cyberark-install,config,samples}

# Store resource suffix
echo "${RESOURCE_SUFFIX}" > "${ARTIFACTS_DIR}/resource-suffix.txt"

echo "[setup] Created directory tree in ${ARTIFACTS_DIR} for demo resources"
echo "[setup] Resources will be created with suffix: ${RESOURCE_SUFFIX}"

# Fetch trust chain certificate from Venafi Cloud
TRUST_CHAIN_FILE="${ARTIFACTS_DIR}/venafi-cloud-built-in-root.pem"
echo "[setup] Fetching built-in root certificate from ${CLOUD_URL}..."

RESPONSE=$(curl -sS -H "tppl-api-key: ${CYBR_CLOUD_API_KEY}" \
  "${CLOUD_URL}/v1/certificateauthorities/builtin/accounts") || {
    echo "[setup] ❌ Failed to contact Cyberark Certificate Manager Cloud API"
    exit 1
}

CERTS=$(echo "$RESPONSE" | jq -r '.accounts[].account.accountDetails.trustChain[].certificate' || true)

if [[ -z "$CERTS" ]]; then
  echo "[setup] ❌ No certificates found in trust chain response"
  exit 1
fi

echo "$CERTS" > "$TRUST_CHAIN_FILE"

if ! grep -q "BEGIN CERTIFICATE" "$TRUST_CHAIN_FILE"; then
  echo "[setup] ❌ Trust chain content is not valid PEM format"
  exit 1
fi

# # Reorder trust chain: root first
# REORDERED_FILE="${ARTIFACTS_DIR}/venafi-cloud-root-first.pem"
# TEMP_DIR=$(mktemp -d)

# # Split into individual certs using awk
# awk '
# /-----BEGIN CERTIFICATE-----/ {
#   if (out) close(out);
#   out = sprintf("%s/cert_%d.pem", dir, ++i);
# }
# { print > out }
# ' dir="$TEMP_DIR" "$TRUST_CHAIN_FILE"

# ROOT_CERT=""
# INTERMEDIATE_CERTS=()

# for cert in "$TEMP_DIR"/cert_*.pem; do
#   if [[ -s "$cert" ]]; then
#     SUBJECT=$(openssl x509 -in "$cert" -noout -subject | cut -d'=' -f2- | tr -d '[:space:]')
#     ISSUER=$(openssl x509 -in "$cert" -noout -issuer | cut -d'=' -f2- | tr -d '[:space:]')

#     if [[ "$SUBJECT" == "$ISSUER" ]]; then
#       ROOT_CERT="$cert"
#     else
#       INTERMEDIATE_CERTS+=("$cert")
#     fi
#   fi
# done

# if [[ -z "$ROOT_CERT" ]]; then
#   echo "[setup] ❌ Could not identify root certificate in trust chain"
#   exit 1
# fi

# #cat "$ROOT_CERT" "${INTERMEDIATE_CERTS[@]:-}" > "$REORDERED_FILE"
# #mv "$REORDERED_FILE" "$TRUST_CHAIN_FILE"

# mv "$ROOT_CERT" "$TRUST_CHAIN_FILE"

echo "[setup] ✅ Trust Anchor saved to: $TRUST_CHAIN_FILE"

# Placeholder: dependency checks
# Example:
# command -v kubectl >/dev/null || { echo "kubectl not found"; exit 1; }
# command -v jq >/dev/null || { echo "jq not found"; exit 1; }

echo "[setup] Environment preparation complete."
