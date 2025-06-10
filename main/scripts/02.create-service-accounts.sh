#!/bin/bash

set -euo pipefail

echo "[create-service-accounts] Creating CyberArk Certificate Manager service accounts..."

# Validate env vars
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR is required}"
: "${CYBR_TEAM_NAME:?CYBR_TEAM_NAME is required}"
: "${CYBR_CLOUD_API_KEY:?CYBR_CLOUD_API_KEY is required}"

# Check dependencies
command -v venctl >/dev/null || { echo "[ERROR] venctl not found in PATH"; exit 1; }
command -v jq >/dev/null || { echo "[ERROR] jq not found in PATH"; exit 1; }

# Handle suffix override from file
SUFFIX_FILE="${ARTIFACTS_DIR}/resource-suffix.txt"
if [ -f "$SUFFIX_FILE" ]; then
  RESOURCE_SUFFIX="$(<"$SUFFIX_FILE")"
  echo "Overriding RESOURCE_SUFFIX with value from file: $RESOURCE_SUFFIX"
else
  : "${RESOURCE_SUFFIX:?RESOURCE_SUFFIX is required or missing from suffix file}"
fi

INSTALL_DIR="${ARTIFACTS_DIR}/cyberark-install"

echo "Generating service accounts using suffix '${RESOURCE_SUFFIX}' for team '${CYBR_TEAM_NAME}'"

## 1. Kubernetes Certificate Discovery Service Account
echo "[create-service-accounts] Creating Discovery service account..."
venctl iam service-accounts agent create \
  --name "mis-demo-agent-${RESOURCE_SUFFIX}" \
  --output-file "${INSTALL_DIR}/cybr_mis_agent_secret.json" \
  --output "secret" \
  --owning-team "${CYBR_TEAM_NAME}" \
  --validity 10 \
  --api-key "${CYBR_CLOUD_API_KEY}" \
  --vcp-region "${CYBR_CLOUD_REGION}"

jq -r '.private_key' "${INSTALL_DIR}/cybr_mis_agent_secret.json" > "${INSTALL_DIR}/cybr_mis_agent_secret.yaml"
jq -r '.client_id' "${INSTALL_DIR}/cybr_mis_agent_secret.json" > "${INSTALL_DIR}/cybr_mis_agent_client_id.txt"

## 2. CyberArk Registry Service Account
echo "[create-service-accounts] Creating Registry service account..."
venctl iam service-account registry create \
  --name "mis-demo-secret-${RESOURCE_SUFFIX}" \
  --output-file "${INSTALL_DIR}/cybr_mis_registry_secret.json" \
  --output "secret" \
  --owning-team "${CYBR_TEAM_NAME}" \
  --validity 10 \
  --scopes enterprise-cert-manager,enterprise-approver-policy,enterprise-venafi-issuer \
  --api-key "${CYBR_CLOUD_API_KEY}" \
  --vcp-region "${CYBR_CLOUD_REGION}"

jq -r '.image_pull_secret' "${INSTALL_DIR}/cybr_mis_registry_secret.json" > "${INSTALL_DIR}/cybr_mis_registry_secret.yaml"

#temporary - while we can create registry secret using singapore
#cp ~/tmp/cybr_mis_registry_secret.yaml "${INSTALL_DIR}/cybr_mis_registry_secret.yaml"

## 3. CyberArk WIM (Firefly) Service Account
echo "[create-service-accounts] Creating Firefly (WIM) service account..."
venctl iam service-accounts firefly create \
  --name "mis-demo-firefly-${RESOURCE_SUFFIX}" \
  --output-file "${INSTALL_DIR}/cybr_mis_firefly_secret.json" \
  --output "secret" \
  --owning-team "${CYBR_TEAM_NAME}" \
  --validity 10 \
  --api-key "${CYBR_CLOUD_API_KEY}" \
  --vcp-region "${CYBR_CLOUD_REGION}"

jq -r '.private_key' "${INSTALL_DIR}/cybr_mis_firefly_secret.json" > "${INSTALL_DIR}/cybr_mis_firefly_secret.yaml"
jq -r '.client_id' "${INSTALL_DIR}/cybr_mis_firefly_secret.json" > "${INSTALL_DIR}/cybr_mis_firefly_client_id.txt"

echo " "
echo "[create-service-accounts] All service accounts created successfully."
echo "####################################################################"
echo "Associate the Workload Identity Manager Service Account in the UI"
echo "####################################################################"