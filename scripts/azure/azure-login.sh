#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/env-vars.sh}"
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

throw_error() { echo "ERROR: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

echo "==> Checking required CLI..."
have az || throw_error "Azure CLI (az) not found. Install: https://aka.ms/azure-cli"

echo "==> Azure CLI version:"
az version --query '"azure-cli"' -o tsv 2>/dev/null || {
  # Fallback if --query fails for some reason
  az --version 2>/dev/null | head -n 1 || true
}

TENANT_OPT=()
[[ -n "${AZ_TENANT_ID:-}" ]] && TENANT_OPT=(--tenant "${AZ_TENANT_ID}")

echo "==> Logging into Azure (device code flow)..."
# --only-show-errors reduces chatty output
 az login --use-device-code "${TENANT_OPT[@]}" --only-show-errors >/dev/null

if [[ -n "${AZ_SUBSCRIPTION_ID:-}" ]]; then
  echo "==> Setting subscription: ${AZ_SUBSCRIPTION_ID}"
  az account set --subscription "${AZ_SUBSCRIPTION_ID}" --only-show-errors
fi

echo "==> Active account:"
 az account show \
  --query "{name:name, id:id, tenant:tenantId}" -o table --only-show-errors

echo "==> Done."
