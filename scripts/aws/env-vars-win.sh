#!/bin/bash
# env-vars-win.sh — Windows nodegroup specific variables

# IAM role for cluster control plane (optional — used by eks-windows-node.sh add)
# Example: eksctl-<cluster>-cluster-ServiceRole
EKS_CLUSTER_ROLE_NAME="${EKS_CLUSTER_ROLE_NAME:-}"

# Windows node group params
WINDOWS_NODEGROUP_NAME="${WINDOWS_NODEGROUP_NAME:-win-worker}"
WINDOWS_NODE_TYPE="${WINDOWS_NODE_TYPE:-m5.large}"
WINDOWS_NODES="${WINDOWS_NODES:-1}"
WINDOWS_NODES_MIN="${WINDOWS_NODES_MIN:-1}"
WINDOWS_NODES_MAX="${WINDOWS_NODES_MAX:-1}"

# AMI family & storage
WINDOWS_AMI_FAMILY="${WINDOWS_AMI_FAMILY:-WindowsServer2022FullContainer}"
WINDOWS_VOLUME_SIZE="${WINDOWS_VOLUME_SIZE:-100}"

# Optional labels/taints
WINDOWS_LABELS="${WINDOWS_LABELS:-Environment=dev,Team=platform}"
WINDOWS_TAINTS="${WINDOWS_TAINTS:-}"

# Higher pod density (optional)
ENABLE_WINDOWS_PREFIX_DELEGATION="${ENABLE_WINDOWS_PREFIX_DELEGATION:-false}"
