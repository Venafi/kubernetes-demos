#!/bin/bash

set -euo pipefail

echo "[prepare-kubernetes] Creating namespaces and configuring secrets..."

# Validate required environment variables
: "${K8S_NAMESPACE:?K8S_NAMESPACE is required}"
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR is required}"

NAMESPACES_DIR="namespaces"
INSTALL_DIR="${ARTIFACTS_DIR}/cyberark-install"

# Validate namespace files
for ns_file in "${NAMESPACES_DIR}"/*.yaml; do
  if [[ ! -s "$ns_file" ]]; then
    echo "[ERROR] Namespace file missing or empty: $ns_file"
    exit 1
  fi
  echo "[prepare-kubernetes] Applying namespace from $ns_file"
  kubectl apply -f "$ns_file"
done

# Validate secrets exist
for secret in cybr_mis_agent_secret.yaml cybr_mis_registry_secret.yaml cybr_mis_firefly_secret.yaml; do
  secret_file="${INSTALL_DIR}/${secret}"
  if [[ ! -s "$secret_file" ]]; then
    echo "[ERROR] Missing or empty secret file: $secret_file"
    exit 1
  fi
  echo "[prepare-kubernetes] Applying secret $secret_file to namespace $K8S_NAMESPACE"
  kubectl -n "$K8S_NAMESPACE" apply -f "$secret_file"
done

# Placeholder for any pre-requirements
# e.g., kubectl apply -f crds.yaml

echo "[prepare-kubernetes] Namespaces and secrets applied successfully."
