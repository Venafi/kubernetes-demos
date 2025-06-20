#!/bin/bash

#!/bin/bash

set -euo pipefail

CONFIG_FILE="${EKS_CONFIG:-./eks-config.sh}"
FORCE=false

# Parse args
ACTION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    create|delete|describe)
      ACTION="$1"
      ;;
    --config)
      CONFIG_FILE="$2"
      shift
      ;;
    --force)
      FORCE=true
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Config file not found: $CONFIG_FILE"
  exit 1
fi

echo "📄 Using config file: $CONFIG_FILE"
source "$CONFIG_FILE"

usage() {
  echo "Usage: $0 {create|delete|describe} [--config ./file] [--force]"
  exit 1
}

case "$ACTION" in
  create)
    echo "🚀 Creating EKS cluster '$CLUSTER_NAME' in region '$REGION'..."

    CMD=(eksctl create cluster
      --name "$CLUSTER_NAME"
      --version "$K8S_VERSION"
      --region "$REGION"
      --nodegroup-name "$NODEGROUP_NAME"
      --node-type "$NODE_TYPE"
      --nodes "$NODES"
      --nodes-min "$NODES_MIN"
      --nodes-max "$NODES_MAX"
      --profile "$PROFILE"
      --tags "$TAGS"
    )

    [[ "$ENABLE_OIDC" == "true" ]] && CMD+=(--with-oidc)
    [[ "$MANAGED_NODEGROUP" == "true" ]] && CMD+=(--managed)

    echo "🧱 Running: ${CMD[*]}"
    "${CMD[@]}"
    ;;

  delete)
    if [[ "$FORCE" == "false" ]]; then
      echo "⚠️ About to delete cluster '$CLUSTER_NAME'. Use --force to skip this prompt."
      read -p "Type 'yes' to continue: " CONFIRM
      if [[ "$CONFIRM" != "yes" ]]; then
        echo "🛑 Deletion cancelled."
        exit 1
      fi
    fi

    echo "🔥 Deleting EKS cluster '$CLUSTER_NAME'..."
    eksctl delete cluster \
      --name="$CLUSTER_NAME" \
      --region="$REGION" \
      --profile="$PROFILE"
    ;;

  describe)
    echo "🔍 Describing EKS cluster '$CLUSTER_NAME' in region '$REGION'..."

    CLUSTER_JSON=$(aws eks describe-cluster \
      --name "$CLUSTER_NAME" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --output json)

    echo "$CLUSTER_JSON" | jq '.cluster | {
      name,
      status,
      version,
      endpoint,
      createdAt,
      roleArn,
      vpc: .resourcesVpcConfig
    }'

    if [[ "$ENABLE_OIDC" == "true" ]]; then
      echo
      echo "🔐 OIDC Identity Provider:"
      echo "$CLUSTER_JSON" | jq -r '.cluster.identity.oidc.issuer'
    fi
    ;;
esac
