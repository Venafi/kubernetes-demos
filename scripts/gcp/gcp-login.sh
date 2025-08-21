#!/usr/bin/env bash
# gcp-login.sh — ensure gcloud is logged in and required APIs are enabled
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/env-vars.sh}"
# shellcheck disable=SC1090
source "${ENV_FILE}"

require() { command -v "$1" >/dev/null 2>&1 || { echo "FATAL: '$1' not found"; exit 1; }; }
require gcloud
require kubectl

if [[ -z "${PROJECT_ID:-}" ]]; then
  echo "FATAL: PROJECT_ID not set. Edit env-vars.sh"; exit 1
fi

gcloud config set project "${PROJECT_ID}" >/dev/null
[[ -n "${REGION:-}" ]] && gcloud config set compute/region "${REGION}" >/dev/null
[[ -n "${ZONE:-}"   ]] && gcloud config set compute/zone "${ZONE}"   >/dev/null

# Login if needed
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
  echo "No active gcloud account — opening login..."
  gcloud auth login --brief
else
  echo "Already logged in to gcloud."
fi
# ADC for libraries
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "Setting up Application Default Credentials..."
  gcloud auth application-default login --quiet
fi

#echo "Enabling required APIs (idempotent)..."
#gcloud services enable   container.googleapis.com   privateca.googleapis.com   iam.googleapis.com   iamcredentials.googleapis.com   cloudresourcemanager.googleapis.com   serviceusage.googleapis.com >/dev/null 2>&1 || true

echo "gcp-login.sh: ready (project=${PROJECT_ID}, region=${REGION}, zone=${ZONE:-n/a})"
