#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Default config name (for single reset)
CONFIG_NAME="${1:-firefly-config-built-in-ca}"

# Optional: support list of configs via env var
CONFIG_LIST=(
  "firefly-config-built-in-ca"
  "WIM-config-for-builtin-ca"
  "WIM-config-CCM-self-hosted"
  "WIM-config-for-ZTPKI"
)

# Helper: reset a single config name
reset_config() {
  local name="$1"

  echo "[reset] Using Cloud URL: $CLOUD_URL"
  echo "[reset] Fetching Workload Identity Manager UUID for config: $name..."

  local CONFIG_ID
  CONFIG_ID=$(curl -sS \
    -H "accept: application/json" \
    -H "tppl-api-key: $CYBR_CLOUD_API_KEY" \
    "$CLOUD_URL/v1/distributedissuers/configurations" | \
    jq -r --arg name "$name" '.configurations[] | select(.name == $name) | .id')

  if [[ -z "$CONFIG_ID" ]]; then
    echo "[reset] ⚠️  Firefly configuration '$name' not found"
    return
  fi

  echo "[reset] Found configuration ID: $CONFIG_ID"

  local RESPONSE
  RESPONSE=$(curl -sS -w "%{http_code}" --fail \
    --request PATCH \
    --url "$CLOUD_URL/v1/distributedissuers/configurations/${CONFIG_ID}" \
    --header 'accept: application/json' \
    --header 'content-type: application/json' \
    --header "tppl-api-key: ${CYBR_CLOUD_API_KEY}" \
    --data '{"serviceAccountIds": []}' \
    -o /tmp/firefly_patch_response.json)

  if [[ "$RESPONSE" -ne 200 ]]; then
    echo "[reset] ❌ Failed to patch Firefly config '$name' (HTTP $RESPONSE)"
    cat /tmp/firefly_patch_response.json | jq .
  else
    echo "[reset] ✅ Successfully disassociated service accounts from Firefly config '$name'"
  fi
}

# Decide what to reset
if [[ -n "${1:-}" ]]; then
  reset_config "$CONFIG_NAME"
else
  echo "[reset] No CONFIG_NAME provided — resetting known defaults..."
  for cfg in "${CONFIG_LIST[@]}"; do
    reset_config "$cfg"
  done
fi

echo "[reset] Complete."
