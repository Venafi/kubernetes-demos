#!/bin/bash

# === Cluster Config ===
export ROSA_CLUSTER_NAME="my-rosa"
export ROSA_REGION="us-east-2"
export ROSA_AWS_ROLES_PREFIX="my-rosa"
export ROSA_DOMAIN_PREFIX="my-domain"
export ROSA_PROFILE="my-aws-profile"
# if your AWS and Redhat subscriptions are not connected, set hosted_control_plane setting = false
export ROSA_HOSTED_CP=true

# === Networking ===
export ROSA_NETWORK_STACK_NAME="${ROSA_CLUSTER_NAME}-nw-stack"

# === Access Control ===
export MY_PUBLIC_IP=$(curl -s https://checkip.amazonaws.com)
export ROSA_ALLOWED_CIDRS="${MY_PUBLIC_IP}/32"
export ROSA_ADMIN_PASSWORD="DEMO_CLUSTER_ACCESS_PASS_TO_SET"

# === Tagging ===
export ROSA_TAGS="CreatedBy me,cluster my-rosa"

# === Versioning ===
export ROSA_VERSION="4.18.19"
