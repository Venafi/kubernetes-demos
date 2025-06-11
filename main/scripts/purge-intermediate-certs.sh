#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[purge] Using Cloud URL: $CLOUD_URL"
echo "[purge] Fetching intermediate certificate UUIDs..."

EXCLUDE_FILE="${SCRIPTS_DIR}/excluded-uuids.txt"
EXCLUDE_LIST=()

if [[ -f "$EXCLUDE_FILE" ]]; then
  echo "[purge] Loading exclusion list from $EXCLUDE_FILE"
  while IFS= read -r line; do
    entry=$(echo "$line" | sed 's/#.*//' | xargs)  # strip comment + trim
    [[ -n "$entry" ]] && EXCLUDE_LIST+=("$entry")
  done < "$EXCLUDE_FILE"
fi

UUIDS=$(curl -s --location \
  --header "tppl-api-key: ${CYBR_CLOUD_API_KEY}" \
  --header 'Content-Type: application/json' \
  "${CLOUD_URL}/v1/distributedissuers/intermediatecertificates" \
  | jq -r '.intermediateCertificates[].id')

if [[ -z "$UUIDS" ]]; then
  echo "[purge] No intermediate certificates found."
  exit 0
fi

echo "[purge] Found $(echo "$UUIDS" | wc -l) certificate(s). Filtering and deleting..."

for uuid in $UUIDS; do
  uuid_trimmed=$(echo "$uuid" | tr -d '\t\r' | xargs)
  if printf '%s\n' "${EXCLUDE_LIST[@]}" | grep -q -x "$uuid_trimmed"; then
    echo "🚫 Skipping excluded UUID: $uuid_trimmed"
    continue
  fi

  echo "→ Deleting certificate $uuid_trimmed..."
  RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" --location \
  --request DELETE "${CLOUD_URL}/v1/distributedissuers/intermediatecertificates/${uuid_trimmed}" \
  --header "tppl-api-key: ${CYBR_CLOUD_API_KEY}" \
  --header 'Content-Type: application/json')

  echo "🧾 Response:"
  echo "$RESPONSE"

  # Extract status and log body
#  HTTP_BODY=$(echo "$RESPONSE" | sed '/^HTTP_STATUS:/d')
#  HTTP_STATUS=$(echo "$RESPONSE" | sed -n 's/^HTTP_STATUS://p')

#  echo "❌ Failed to delete $uuid_trimmed (status: $HTTP_STATUS)"
#  echo "[curl] Response body:"
#  echo "$HTTP_BODY"
done

echo "[purge] Complete."
