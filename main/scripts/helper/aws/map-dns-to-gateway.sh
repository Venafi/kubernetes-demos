#!/usr/bin/env bash

set -euo pipefail

ZONE="${1:-}"
DNS_NAME="${2:-}"
PROFILE="${3:-}"
TARGET="${4:-}"

if [[ -z "$ZONE" || -z "$DNS_NAME" || -z "$PROFILE" || -z "$TARGET" ]]; then
  echo "Usage: $0 <hosted-zone-id> <dns-name> <aws-profile> <ip-or-hostname>"
  exit 1
fi

# Decide record type
if [[ "$TARGET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  TYPE="A"
else
  TYPE="CNAME"
fi

echo "[map-dns] Preparing Route 53 record for $DNS_NAME → $TARGET"

CHANGE_BATCH=$(jq -n \
  --arg name "${DNS_NAME}." \
  --arg type "$TYPE" \
  --arg value "$TARGET" \
  '{
    Changes: [{
      Action: "UPSERT",
      ResourceRecordSet: {
        Name: $name,
        Type: $type,
        TTL: 300,
        ResourceRecords: [{ Value: $value }]
      }
    }]
  }')

echo "[map-dns] 🔍 Record preview:"
echo "$CHANGE_BATCH" | jq .

# Save manual command
RECOMMENDED_CMD="aws --profile \"$PROFILE\" route53 change-resource-record-sets \\
  --hosted-zone-id \"$ZONE\" \\
  --change-batch '$(echo "$CHANGE_BATCH" | jq -c .)'"

echo "$RECOMMENDED_CMD" > /tmp/map-dns-cmd.sh

# Try to apply (if credentials work)
if aws sts get-caller-identity --profile "$PROFILE" >/dev/null 2>&1; then
  aws --profile "$PROFILE" route53 change-resource-record-sets \
    --hosted-zone-id "$ZONE" \
    --change-batch "$CHANGE_BATCH"
  echo "[map-dns] ✅ DNS updated: $DNS_NAME → $TARGET"
else
  echo "[map-dns] 🛑 Skipped DNS update (not authenticated). Saved manual command to /tmp/map-dns-cmd.sh"
  exit 2
fi
