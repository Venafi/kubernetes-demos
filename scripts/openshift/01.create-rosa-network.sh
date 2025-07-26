#!/bin/bash
set -euo pipefail
source ./env-vars.sh

if [[ -z "$ROSA_NETWORK_STACK_NAME" || -z "$ROSA_REGION" || -z "$ROSA_CLUSTER_NAME" ]]; then
  echo "❌ ROSA_NETWORK_STACK_NAME, ROSA_REGION, and ROSA_CLUSTER_NAME must be set in env-vars.sh"
  exit 1
fi

TMP_SUBNET_FILE="subnet-ids-${ROSA_CLUSTER_NAME}.env"

# Step 1: Create the network stack

echo "🚀 Creating network stack via ROSA CLI: $ROSA_NETWORK_STACK_NAME in $ROSA_REGION"

rosa create network \
  --param Name="$ROSA_NETWORK_STACK_NAME" \
  --param Region="$ROSA_REGION" \
  --param AvailabilityZoneCount=1 \
  --param VpcCidr=10.0.0.0/16

# Step 2: Extract subnet IDs from CloudFormation output

echo "🔍 Retrieving subnet IDs from CloudFormation stack: $ROSA_NETWORK_STACK_NAME"

network_info=$(aws cloudformation describe-stacks \
  --stack-name "$ROSA_NETWORK_STACK_NAME" \
  --region "$ROSA_REGION" \
  --profile "$ROSA_PROFILE" \
  --query "Stacks[0].Outputs" \
  --output json)

public_subnets=$(echo "$network_info" | jq -r '.[] | select(.OutputKey | test("PublicSubnet")) | .OutputValue')
private_subnets=$(echo "$network_info" | jq -r '.[] | select(.OutputKey | test("PrivateSubnet")) | .OutputValue')

if [[ -z "$public_subnets" || -z "$private_subnets" ]]; then
  echo "❌ Failed to extract subnet IDs from stack outputs."
  exit 1
fi

public_csv=$(echo "$public_subnets" | paste -sd "," -)
private_csv=$(echo "$private_subnets" | paste -sd "," -)

# Step 3: Write to temporary file
cat <<EOF > "$TMP_SUBNET_FILE"
# Auto-generated subnet list for cluster $ROSA_CLUSTER_NAME
export ROSA_PUBLIC_SUBNETS="$public_csv"
export ROSA_PRIVATE_SUBNETS="$private_csv"
EOF

echo "📄 Subnet IDs written to $TMP_SUBNET_FILE"

# Step 4: Tag subnets
for subnet in $public_subnets; do
  echo "🏷️ Tagging public subnet $subnet"
  aws ec2 create-tags \
    --region "$ROSA_REGION" \
    --profile "$ROSA_PROFILE" \
    --resources "$subnet" \
    --tags Key=kubernetes.io/cluster/$ROSA_CLUSTER_NAME,Value=owned \
           Key=kubernetes.io/role/elb,Value=1

done

for subnet in $private_subnets; do
  echo "🏷️ Tagging private subnet $subnet"
  aws ec2 create-tags \
    --region "$ROSA_REGION" \
    --profile "$ROSA_PROFILE" \
    --resources "$subnet" \
    --tags Key=kubernetes.io/cluster/$ROSA_CLUSTER_NAME,Value=owned \
           Key=kubernetes.io/role/internal-elb,Value=1

done

echo "✅ Network creation using CloudFormation and subnet tagging complete. $TMP_SUBNET_FILE will be sourced during cluster creation and used for --subnet-ids."