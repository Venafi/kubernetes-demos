#!/bin/bash
set -euo pipefail
source ./env-vars.sh

START_TIME=$(date +%s)

patch_security_groups() {
  LOG_FILE="patch-sg-rules.log"
  echo "🔍 Starting SG patch process using tag: api.openshift.com/name = $ROSA_CLUSTER_NAME" | tee "$LOG_FILE"

  if [[ -z "$ROSA_ALLOWED_CIDRS" ]]; then
    echo "❌ ROSA_ALLOWED_CIDRS must be set in env-vars.sh" | tee -a "$LOG_FILE"
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo "🕒 Total elapsed time: $((DURATION / 60)) min $((DURATION % 60)) sec"
    exit 1
  fi

  # Standard and extended ports for console access
  PORTS=(443 6443 80)
  ADDITIONAL_PORT_RANGE="1024-65535"

  SG_IDS=$(aws ec2 describe-security-groups \
    --region "$ROSA_REGION" \
    --profile "$ROSA_PROFILE" \
    --filters "Name=tag:api.openshift.com/name,Values=$ROSA_CLUSTER_NAME" \
    --query 'SecurityGroups[*].GroupId' \
    --output text)

  if [[ -z "$SG_IDS" ]]; then
    echo "⚠️ No security groups found with api.openshift.com/name: $ROSA_CLUSTER_NAME" | tee -a "$LOG_FILE"
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo "🕒 Total elapsed time: $((DURATION / 60)) min $((DURATION % 60)) sec"
    exit 0
  fi

  echo "✅ Found security groups: $SG_IDS" | tee -a "$LOG_FILE"

  for sg_id in $SG_IDS; do
    echo -e "\n🔧 Patching security group: $sg_id" | tee -a "$LOG_FILE"
    for port in "${PORTS[@]}"; do
      echo "   🔎 Checking port $port for CIDR $ROSA_ALLOWED_CIDRS" | tee -a "$LOG_FILE"
      rule_exists=$(aws ec2 describe-security-groups \
        --region "$ROSA_REGION" \
        --profile "$ROSA_PROFILE" \
        --group-ids "$sg_id" \
        --query "SecurityGroups[].IpPermissions[?ToPort==\`${port}\`].IpRanges[].CidrIp" \
        --output text | grep -F "$ROSA_ALLOWED_CIDRS" || true)
      if [[ -z "$rule_exists" ]]; then
        echo "   ➕ Adding rule for port $port to allow $ROSA_ALLOWED_CIDRS" | tee -a "$LOG_FILE"
        aws ec2 authorize-security-group-ingress \
          --region "$ROSA_REGION" \
          --profile "$ROSA_PROFILE" \
          --group-id "$sg_id" \
          --protocol tcp \
          --port "$port" \
          --cidr "$ROSA_ALLOWED_CIDRS" | tee -a "$LOG_FILE"
      else
        echo "   ✅ Rule already exists for port $port and CIDR $ROSA_ALLOWED_CIDRS" | tee -a "$LOG_FILE"
      fi
    done

    echo "   🔎 Checking ephemeral port range $ADDITIONAL_PORT_RANGE for CIDR $ROSA_ALLOWED_CIDRS" | tee -a "$LOG_FILE"
    aws ec2 authorize-security-group-ingress \
      --region "$ROSA_REGION" \
      --profile "$ROSA_PROFILE" \
      --group-id "$sg_id" \
      --protocol tcp \
      --port "$ADDITIONAL_PORT_RANGE" \
      --cidr "$ROSA_ALLOWED_CIDRS" || true

  done

  echo -e "\n✅ Security group patching complete. Log saved to $LOG_FILE"
}

check_cluster_status() {
  echo "⏳ Waiting for cluster to reach 'ready' state..."
  while true; do
    if ! rosa whoami --profile "$ROSA_PROFILE" &>/dev/null; then
      echo "❌ ROSA token expired or invalid. Please re-authenticate using 'rosa login --use-auth-code'."
      echo "ℹ️  After logging in, run './03.create-rosa-cluster.sh update-security-groups' to finish setup."
      exit 1
    fi

    status=$(rosa describe cluster -c "$ROSA_CLUSTER_NAME" --region "$ROSA_REGION" --profile "$ROSA_PROFILE" --output json | jq -r '.state')
    case "$status" in
      ready)
        echo "✅ Cluster is ready."
        break
        ;;
      error)
        echo "❌ Cluster entered an error state."
        exit 1
        ;;
      *)
        echo "🔄 Current status: $status. Sleeping 60s..."
        sleep 60
        ;;
    esac
  done
}

create_cluster() {
  SUBNET_FILE="subnet-ids-${ROSA_CLUSTER_NAME}.env"
  if [[ -f "$SUBNET_FILE" ]]; then
    source "$SUBNET_FILE"
  else
    echo "❌ Subnet ID file $SUBNET_FILE not found. Run 01.create-rosa-network.sh first."
    exit 1
  fi

  OIDC_ID=$(cat .oidc-id 2>/dev/null || true)
  if [[ -z "$OIDC_ID" ]]; then
    echo "❌ Missing .oidc-id. Run setup-rosa-iam.sh first."
    exit 1
  fi

  echo "🚀 Creating public ROSA HCP cluster using tagged public + private subnets..."
  rosa create cluster \
    $( [[ "${ROSA_HOSTED_CP:-false}" == "true" ]] && echo "--hosted-cp" ) \
    --cluster-name "$ROSA_CLUSTER_NAME" \
    --region "$ROSA_REGION" \
    --operator-roles-prefix "$ROSA_AWS_ROLES_PREFIX" \
    --domain-prefix "$ROSA_DOMAIN_PREFIX" \
    --sts \
    --mode auto \
    --profile "$ROSA_PROFILE" \
    --tags "$ROSA_TAGS" \
    --create-admin-user \
    --cluster-admin-password "$ROSA_ADMIN_PASSWORD" \
    --oidc-config-id "$OIDC_ID" \
    --subnet-ids "$ROSA_PUBLIC_SUBNETS,$ROSA_PRIVATE_SUBNETS" \
    --yes
  echo "✅ Cluster creation command submitted."
}

usage() {
  echo "Usage: $0 [option]"
  echo "Options:"
  echo "  update-security-groups   Only patch security groups"
  echo "  status                   Check cluster readiness"
  echo "  full-setup               Run full flow: create + status + patch"
}

case "${1:-}" in
  update-security-groups)
    patch_security_groups
    ;;
  status)
    check_cluster_status
    ;;
  full-setup)
    create_cluster
    check_cluster_status
    patch_security_groups
    ;;
  *)
    usage
    exit 1
    ;;
esac

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "🕒 Total elapsed time: $((DURATION / 60)) min $((DURATION % 60)) sec"
