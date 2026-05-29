#!/bin/bash
set -euo pipefail
source ./env-vars.sh

echo "🔐 Fetching API endpoint and admin credentials..."

api_url=$(rosa describe cluster -c "$ROSA_CLUSTER_NAME" --region "$ROSA_REGION" --profile "$ROSA_PROFILE" --output json | jq -r '.api.url')
#username=$(rosa describe admin -c "$ROSA_CLUSTER_NAME" --region "$ROSA_REGION" --profile "$ROSA_PROFILE" --output json | jq -r '.username')
username="cluster-admin"
password="${ROSA_ADMIN_PASSWORD}"

echo "📥 Logging in with oc..."
oc login "$api_url" -u "$username" -p "$password" --certificate-authority="${CLUSTER_CA_CERT}"

kcfg="kubeconfig-${ROSA_CLUSTER_NAME}.yaml"
oc config view --raw > "$kcfg"
export KUBECONFIG="$kcfg"
echo "✅ kubeconfig saved to: $kcfg"
