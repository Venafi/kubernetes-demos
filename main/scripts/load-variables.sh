#!/bin/bash

VARS_FILE="$(dirname "$0")/../main/env/env-vars.sh"
VERSIONS_FILE="$(dirname "$0")/../main/env/component-versions.sh"

if [ ! -f "$VARS_FILE" ]; then
  echo "[load-variables] ERROR: env-vars.sh not found at $VARS_FILE"
  exit 1
fi

if [ ! -f "$VERSIONS_FILE" ]; then
  echo "[load-variables] ERROR: component-versions.sh not found at $VERSIONS_FILE"
  exit 1
fi

source "$VARS_FILE"
source "$VERSIONS_FILE"

# Required variables
REQUIRED_VARS=("CYBR_TEAM_NAME" "CYBR_CLOUD_API_KEY")

for VAR in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!VAR:-}" ]; then
    echo "[load-variables] ERROR: Required variable '$VAR' is not set in vars.sh"
    exit 1
  fi
done

REGION_NORMALIZED=$(echo "${CYBR_CLOUD_REGION:-}" | tr '[:upper:]' '[:lower:]')
if [ -z "${CYBR_CLOUD_REGION:-}" ] || [ "$REGION_NORMALIZED" == "us" ]; then
  export CLOUD_URL="https://api.venafi.cloud"
else
  export CLOUD_URL="https://api.${CYBR_CLOUD_REGION}.venafi.cloud"
fi
