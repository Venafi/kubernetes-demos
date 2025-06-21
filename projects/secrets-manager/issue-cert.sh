#!/usr/bin/env bash
set -euo pipefail

# === Auto-load vars.sh if present ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/vars.sh" ]] && source "${SCRIPT_DIR}/vars.sh"

# === Config (override via vars.sh or env) ===
: "${CSM_TENANT:=conjur-tenant-name}"
: "${CONJUR_ACCOUNT:=conjur}"
: "${ISSUER_NAME:=my-cert-issuer}"
: "${CSM_WORKLOAD_ID:=host/data/my-cert-issuer-workload}"
: "${CSM_WORKLOAD_APIKEY:?CSM_WORKLOAD_APIKEY required}"

: "${CERT_NAME:=mycert.svc.cluster.local}"
: "${ORGANIZATION:=CyberArk Inc.}"
: "${CERT_DURATION:=P10D}"
: "${ZONE:=CloudApps\\Default}"
: "${URI_NAMES:="spiffe://cluster.local/ns/cloudapps/sa/app-sa"}"
IFS=' ' read -r -a URI_NAMES <<< "$URI_NAMES"

# === Derived values ===
CSM_SAAS_URL="https://${CSM_TENANT}.secretsmgr.cyberark.cloud"
ENCODED_WRKLD_ID=$(printf '%s' "$CSM_WORKLOAD_ID" | sed 's/\//%2F/g')
TMP_DIR="/tmp/${CERT_NAME}"
mkdir -p "$TMP_DIR"

# === JSON Payload ===
PAYLOAD=$(jq -n \
  --arg cn "$CERT_NAME" \
  --arg org "$ORGANIZATION" \
  --arg ttl "$CERT_DURATION" \
  --arg zone "$ZONE" \
  --arg key_type "RSA_2048" \
  --arg dns "$CERT_NAME" \
  --argjson uri_names "$(printf '%s\n' "${URI_NAMES[@]}" | jq -R . | jq -s .)" \
  '{
    subject: { common_name: $cn, organization: $org },
    key_type: $key_type,
    alt_names: {
      dns_names: [$dns],
      uris: $uri_names
    },
    ttl: $ttl,
    zone: $zone
  }')

# === Get Token from Cyberark Secrets Manager ===
TOKEN_FROM_CSM=$(curl -s \
  --header "Accept-Encoding: base64" \
  --data "$CSM_WORKLOAD_APIKEY" \
  "${CSM_SAAS_URL}/api/authn/${CONJUR_ACCOUNT}/${ENCODED_WRKLD_ID}/authenticate")

# === Issue Certificate with the issuer configured in Secrets Manager + Zone defined in Certificate Manager ===
RESPONSE=$(curl -sS \
  --header "Authorization: Token token=\"$TOKEN_FROM_CSM\"" \
  --header "Accept: application/x.secretsmgr.v2beta+json" \
  --header "Content-Type: application/json" \
  --data "$PAYLOAD" \
  "${CSM_SAAS_URL}/api/issuers/${ISSUER_NAME}/issue")

# === Write Outputs ===
echo "$RESPONSE" > "$TMP_DIR/response.json"
jq -r '.certificate' <<< "$RESPONSE" > "$TMP_DIR/${CERT_NAME}.pem"
jq -r '.chain[]' <<< "$RESPONSE" > "$TMP_DIR/${CERT_NAME}-chain.pem"
jq -r '.private_key' <<< "$RESPONSE" > "$TMP_DIR/${CERT_NAME}-key.pem"

echo "✅ Cert saved in: $TMP_DIR"
ls -l "$TMP_DIR"
