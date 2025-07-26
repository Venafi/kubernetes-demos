#!/bin/bash
set -euo pipefail
source ./env-vars.sh

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "📊 Dry run enabled. No resources will be deleted."
fi

LOG_FILE="cleanup-missing-resources.log"
echo "💥 Starting ROSA cleanup for cluster: $ROSA_CLUSTER_NAME (profile: $ROSA_PROFILE)"

# Step 1: Delete the cluster
if rosa describe cluster -c "$ROSA_CLUSTER_NAME" --region "$ROSA_REGION" --profile "$ROSA_PROFILE" &>/dev/null; then
  echo "🗑️ Deleting ROSA cluster: $ROSA_CLUSTER_NAME"
  if $DRY_RUN; then
    echo "   (dry-run) Would delete cluster"
  else
    rosa delete cluster \
      --cluster "$ROSA_CLUSTER_NAME" \
      --region "$ROSA_REGION" \
      --profile "$ROSA_PROFILE" \
      --yes

    echo "⏳ Waiting for cluster to be deleted..."
    while rosa describe cluster -c "$ROSA_CLUSTER_NAME" --region "$ROSA_REGION" --profile "$ROSA_PROFILE" &>/dev/null; do
      echo "   🔄 Cluster still exists... sleeping 60s"
      sleep 60
    done
    echo "✅ Cluster deleted."
  fi
else
  echo "✅ Cluster does not exist. Skipping cluster deletion."
fi

# Step 2: Delete operator roles
if $DRY_RUN; then
  echo "   (dry-run) Would delete operator roles"
else
  rosa delete operator-roles \
    --prefix "$ROSA_AWS_ROLES_PREFIX" \
    --mode auto \
    --region "$ROSA_REGION" \
    --profile "$ROSA_PROFILE" \
    --yes || echo "⚠️ Operator roles may already be deleted."
fi

# Step 3: Delete account roles
if $DRY_RUN; then
  echo "   (dry-run) Would delete account roles"
else
  rosa delete account-roles \
    --prefix "$ROSA_AWS_ROLES_PREFIX" \
    --mode auto \
    --region "$ROSA_REGION" \
    --profile "$ROSA_PROFILE" \
    --yes || echo "⚠️ Account roles may already be deleted."
fi

# Step 4: Delete OIDC provider if available
OIDC_ID=$(cat .oidc-id 2>/dev/null || true)
if [[ -n "$OIDC_ID" ]]; then
  if $DRY_RUN; then
    echo "   (dry-run) Would delete OIDC provider"
  else
    rosa delete oidc-provider \
      --oidc-config-id "$OIDC_ID" \
      --region "$ROSA_REGION" \
      --profile "$ROSA_PROFILE" \
      --mode auto \
      --yes || echo "⚠️ OIDC provider may already be deleted."
  fi
else
  echo "✅ No .oidc-id found. Skipping OIDC provider deletion."
fi

# Step 5: Delete VPC network stack (if applicable)
if [[ -n "${ROSA_NETWORK_STACK_NAME:-}" ]]; then
  if $DRY_RUN; then
    echo "   (dry-run) Would delete VPC stack $ROSA_NETWORK_STACK_NAME"
  else
    echo "🧹 Deleting CloudFormation stack: $ROSA_NETWORK_STACK_NAME"
    aws cloudformation delete-stack \
      --stack-name "$ROSA_NETWORK_STACK_NAME" \
      --region "$ROSA_REGION" \
      --profile "$ROSA_PROFILE"

    echo "⏳ Waiting for stack to be deleted..."
    while true; do
      status=$(aws cloudformation describe-stacks \
        --stack-name "$ROSA_NETWORK_STACK_NAME" \
        --region "$ROSA_REGION" \
        --profile "$ROSA_PROFILE" \
        --query "Stacks[0].StackStatus" \
        --output text 2>/dev/null || true)

      if [[ -z "$status" ]]; then
        echo "✅ Stack $ROSA_NETWORK_STACK_NAME successfully deleted."
        break
      fi

      echo "🔄 Current stack status: $status. Sleeping 30s..."
      sleep 30
    done
  fi
fi

# Step 6: Clean up local artifacts
if $DRY_RUN; then
  echo "   (dry-run) Would remove local files"
else
  rm -f .oidc-id
  [[ -f "subnet-ids-${ROSA_CLUSTER_NAME}.env" ]] && rm -f "subnet-ids-${ROSA_CLUSTER_NAME}.env"
  if ls kubeconfig-*.yaml >/dev/null 2>&1; then
    rm -f kubeconfig-*.yaml
    echo "✅ Deleted kubeconfig files"
  else
    echo "✅ No kubeconfig files to delete"
  fi
fi

echo -e "\n✅ ROSA cleanup complete."
