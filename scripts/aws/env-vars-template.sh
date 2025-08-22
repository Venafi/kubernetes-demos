#!/bin/bash
# env-vars.sh — cluster-wide environment variables

# ---- Core cluster identity ----
CLUSTER_NAME="${CLUSTER_NAME:-my-eks}"
REGION="${REGION:-us-east-2}"
PROFILE="${PROFILE:-default}"
K8S_VERSION="${K8S_VERSION:-1.33}"

# ---- Default Linux node group ----
NODEGROUP_NAME="${NODEGROUP_NAME:-my-worker}"
NODE_TYPE="${NODE_TYPE:-t3.medium}"
NODES="${NODES:-4}"
NODES_MIN="${NODES_MIN:-3}"
NODES_MAX="${NODES_MAX:-4}"

# ---- Features ----
ENABLE_OIDC="${ENABLE_OIDC:-true}"
MANAGED_NODEGROUP="${MANAGED_NODEGROUP:-true}"

# ---- Tags ----
TAGS="${TAGS:-CreatedBy=me,Environment=dev,Team=platform}"

# ---- Optional: Windows-specific vars (loaded if present) ----
if [[ -f "${ENV_VARS_WIN_FILE:-./env-vars-win.sh}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_VARS_WIN_FILE:-./env-vars-win.sh}"
fi
