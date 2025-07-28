#!/bin/bash

# === Cluster Config ===
export ROSA_CLUSTER_NAME="my-rosa"
export ROSA_REGION="us-east-2"
export ROSA_AWS_ROLES_PREFIX="${ROSA_CLUSTER_NAME}"
export ROSA_DOMAIN_PREFIX="${ROSA_CLUSTER_NAME}"
export ROSA_PROFILE="my-aws-profile"

# if your AWS and Redhat subscriptions are not connected, set hosted_control_plane setting = false for classic cluster
#export ROSA_HOSTED_CP=true
export ROSA_HOSTED_CP=true

# === Networking ===
export ROSA_NETWORK_STACK_NAME="${ROSA_CLUSTER_NAME}-nw-stack"

# === Access Control ===
export MY_PUBLIC_IP=$(curl -s https://checkip.amazonaws.com)
export ROSA_ALLOWED_CIDRS="${MY_PUBLIC_IP}/32"
export ROSA_ADMIN_PASSWORD="REPLACE_WITH_ANYTHING"

# === Tagging ===
export ROSA_TAGS="CreatedBy me,cluster rosa"

# === Versioning ===
export ROSA_VERSION="4.18.20"
