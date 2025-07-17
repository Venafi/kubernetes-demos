#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_NAME="${1:-firefly-config-built-in-ca}"

echo "[reset] Using Cloud URL: $CLOUD_URL"
echo "[reset] Fetching Workload Identity Manager UUID for config: $CONFIG_NAME..."

FIREFLY_CONFIG_ID=$(curl -sS \
  -H "accept: application/json" \
  -H "tppl-api-key: $CYBR_CLOUD_API_KEY" \
  "$CLOUD_URL/v1/distributedissuers/configurations" | \
  jq -r --arg name "$CONFIG_NAME" '.configurations[] | select(.name == $name) | .id')

if [[ -z "$FIREFLY_CONFIG_ID" ]]; then
  echo "[reset] ❌ Firefly configuration '$CONFIG_NAME' not found"
  exit 1
fi

RESPONSE=$(curl -sS -w "%{http_code}" --fail \
  --request PATCH \
  --url "$CLOUD_URL/v1/distributedissuers/configurations/${FIREFLY_CONFIG_ID}" \
  --header 'accept: application/json' \
  --header 'content-type: application/json' \
  --header "tppl-api-key: ${CYBR_CLOUD_API_KEY}" \
  --data '{"serviceAccountIds": []}' \
  -o /tmp/firefly_patch_response.json)

if [[ "$RESPONSE" -ne 200 ]]; then
  echo "[reset] ❌ Failed to patch Firefly config (HTTP $RESPONSE)"
  cat /tmp/firefly_patch_response.json | jq .
  exit 1
else
  echo "[reset] ✅ Successfully disassociated service accounts from Firefly config"
fi

echo "[reset] Complete."
