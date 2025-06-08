#!/bin/bash

set -euo pipefail

echo "[setup] Preparing environment..."

# Validate required variables
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR not set}"
: "${RESOURCE_SUFFIX:?RESOURCE_SUFFIX not set}"

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

# Placeholder: dependency checks
# Example:
# command -v kubectl >/dev/null || { echo "kubectl not found"; exit 1; }
# command -v jq >/dev/null || { echo "jq not found"; exit 1; }

echo "[setup] Environment preparation complete."
