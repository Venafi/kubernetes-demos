#!/bin/bash
set -euo pipefail

CONFIG_FILE="${EKS_CONFIG:-./env-vars.sh}"
FORCE=false

usage() {
  cat <<USAGE
Usage: $0 {create|delete|status} [--config ./env-vars.sh] [--force]
USAGE
  exit 1
}

# Parse args
ACTION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    create|delete|status)
      ACTION="$1"
      ;;
    --config)
      CONFIG_FILE="$2"; shift
      ;;
    --force)
      FORCE=true
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
  shift
done

# Print usage if no action
[[ -z "${ACTION}" ]] && usage

# Load config
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Config file not found: $CONFIG_FILE"
  exit 1
fi
echo "📄 Using config file: $CONFIG_FILE"
# shellcheck disable=SC1090
source "$CONFIG_FILE"

# Ensure AWS is authenticated for the selected profile/region
ensure_aws_auth() {
  echo "🔐 Verifying AWS authentication (profile: ${PROFILE:-default}, region: ${REGION:-unset})..."
  if ! AWS_PROFILE="$PROFILE" AWS_REGION="$REGION" aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS authentication failed. Check your credentials/profile/region and try again."
    exit 1
  fi
}

case "$ACTION" in
  create)
    ensure_aws_auth
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
    ensure_aws_auth
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
      --profile="$PROFILE" \
      --wait
    ;;

  status)
    ensure_aws_auth
    echo "🔍 Cluster status for '$CLUSTER_NAME' in region '$REGION'..."
    CLUSTER_JSON=$(AWS_PROFILE="$PROFILE" AWS_REGION="$REGION" aws eks describe-cluster \
      --name "$CLUSTER_NAME" \
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

    if [[ "${ENABLE_OIDC:-}" == "true" ]]; then
      echo
      echo "🔐 OIDC Identity Provider:"
      echo "$CLUSTER_JSON" | jq -r '.cluster.identity.oidc.issuer'
    fi
    ;;
esac
