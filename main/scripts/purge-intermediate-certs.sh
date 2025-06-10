#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(dirname "$0")"
#source "$SCRIPTS_DIR/load-variables.sh"
CYBR_CLOUD_API_KEY=
CLOUD_URL=https://api.venafi.cloud

echo "[purge] Using Cloud URL: $CLOUD_URL"
echo "[purge] Fetching intermediate certificate UUIDs..."

# === Exclusion list ===
EXCLUDE_FILE="${SCRIPTS_DIR}/excluded-uuids.txt"
EXCLUDE_LIST=()

if [[ -f "$EXCLUDE_FILE" ]]; then
  echo "[purge] Loading exclusion list from $EXCLUDE_FILE"
  mapfile -t EXCLUDE_LIST < "$EXCLUDE_FILE"
fi

# Fetch UUIDs
UUIDS=$(curl -s --location \
  --header "tppl-api-key: ${CYBR_CLOUD_API_KEY}" \
  --header 'Content-Type: application/json' \
  "${CLOUD_URL}/v1/distributedissuers/intermediatecertificates" | jq -r '.intermediateCertificates[].id')

if [[ -z "$UUIDS" ]]; then
  echo "[purge] No intermediate certificates found."
  exit 0
fi

echo "[purge] Found $(echo "$UUIDS" | wc -l) certificate(s). Filtering and deleting..."

for uuid in $UUIDS; do
  if printf '%s\n' "${EXCLUDE_LIST[@]}" | grep -q -x "$uuid"; then
    echo "🚫 Skipping excluded UUID: $uuid"
    continue
  fi

  echo "→ Deleting certificate $uuid..."
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" --location \
    --request DELETE "${CLOUD_URL}/v1/distributedissuers/intermediatecertificates/${uuid}" \
    --header "tppl-api-key: ${CYBR_CLOUD_API_KEY}" \
    --header 'Content-Type: application/json')

  if [ "$STATUS" = "204" ]; then
    echo "✅ Deleted $uuid"
  else
    echo "❌ Failed to delete $uuid (status: $STATUS)"
  fi
done

echo "[purge] Complete."
