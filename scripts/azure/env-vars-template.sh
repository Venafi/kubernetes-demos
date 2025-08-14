#!/usr/bin/env bash
# ==============================================================================
# AKS environment variables 
# ==============================================================================

# ---- Azure subscription/tenant
export AZ_TENANT_ID="REPLACE_WITH_TENANT_ID"
export AZ_SUBSCRIPTION_ID="REPLACE_WITH_SUBSCRIPTION_ID"

# ---- Naming
export AKS_CLUSTER_NAME="my-aks-cluster"
export AKS_RESOURCE_GROUP="${AKS_CLUSTER_NAME}-rg"

# ---- Region & Node VM. Node VM and region are paired. 
export AZ_LOCATION="southcentralus"
export AKS_NODE_VM_SIZE="Standard_D2s_v5"

# ---- Node pool sizing
export AKS_NODE_COUNT="3"

# ---- Kubernetes version
export AKS_K8S_VERSION="1.32.6"

# ---- Networking
export AKS_NETWORK_PLUGIN="azure"

# ---- Tags
export AZURE_TAGS="CreatedBy=me Purpose=Demo Platform=AKS"

# ---- Cleanup behavior
export DELETE_RESOURCE_GROUP_ON_CLEANUP="true"

# ---- kubeconfig retrieval
export GET_CREDENTIALS_AFTER_CREATE="true"

# ---- Local IP discovery (match prior demos)
# Will try AWS checkip first, then DNS, then ifconfig.me
export LOCAL_IP_CMD='(curl -s https://checkip.amazonaws.com)'
export LOCAL_IP="$(bash -lc "${LOCAL_IP_CMD}" | tr -d "\r\n" )"

# ---- API server allowlist (comma-separated CIDRs). Defaults to your current IP /32.
# Example for multiple sites: "203.0.113.10/32,198.51.100.0/24"
export AKS_API_AUTHORIZED_IPS="${AKS_API_AUTHORIZED_IPS:-${LOCAL_IP}/32}"

# SSH controls
export AKS_NO_SSH_KEY="true"        # Pass --no-ssh-key at create time
export AKS_DISABLE_SSH_SERVICE="true"  # If true, also disable the SSH service (preview)
export AKS_SSH_PUBLIC_KEY=""         # Optional path or inline key if you DO want SSH

# az cli throws some random python warnings - ignoring python errors
export PYTHONWARNINGS="${PYTHONWARNINGS:-ignore}"