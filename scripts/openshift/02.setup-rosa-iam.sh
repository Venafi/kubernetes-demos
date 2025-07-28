#!/bin/bash
set -euo pipefail
source ./env-vars.sh

echo "🚀 [1/3] Creating ROSA account roles..."

rosa create account-roles \
  --mode auto \
  --prefix "$ROSA_AWS_ROLES_PREFIX" \
  --region "$ROSA_REGION" \
  --force-policy-creation \
  --profile "$ROSA_PROFILE" \
  --yes

if [[ "${ROSA_HOSTED_CP:-false}" == "true" ]]; then
  ROLE_NAME_SUFFIX="HCP-ROSA-Installer-Role"
else
  ROLE_NAME_SUFFIX="Installer-Role"
fi

INSTALLER_ROLE_ARN=$(aws iam list-roles \
  --profile "$ROSA_PROFILE" \
  --query "Roles[?RoleName=='${ROSA_AWS_ROLES_PREFIX}-${ROLE_NAME_SUFFIX}'].Arn" \
  --output text)

if [[ -z "$INSTALLER_ROLE_ARN" ]]; then
  echo "❌ Failed to find installer role ARN"
  exit 1
fi

echo "✅ Installer Role ARN: $INSTALLER_ROLE_ARN"

echo "🚀 [2/3] Creating OIDC config (managed)..."

OIDC_CONFIG_JSON=$(rosa create oidc-config \
  --mode auto \
  --managed \
  --region "$ROSA_REGION" \
  --profile "$ROSA_PROFILE" \
  --output json \
  --yes)

OIDC_ID=$(echo "$OIDC_CONFIG_JSON" | jq -r '.id')

if [[ -z "$OIDC_ID" || "$OIDC_ID" == "null" ]]; then
  echo "❌ Failed to retrieve OIDC config ID"
  exit 1
fi

echo "✅ OIDC Config ID: $OIDC_ID"
echo "$OIDC_ID" > .oidc-id

echo "🚀 [3/3] Creating operator roles for ROSA HCP..."

rosa create operator-roles \
  $( [[ "${ROSA_HOSTED_CP:-false}" == "true" ]] && echo "--hosted-cp" ) \
  --prefix "$ROSA_AWS_ROLES_PREFIX" \
  --oidc-config-id "$OIDC_ID" \
  --mode auto \
  --region "$ROSA_REGION" \
  --installer-role-arn "$INSTALLER_ROLE_ARN" \
  --profile "$ROSA_PROFILE" \
  --yes

echo "✅ ROSA IAM pre-reqs are complete."
