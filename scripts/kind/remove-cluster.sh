#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/env-vars.sh" ]] && source "${SCRIPT_DIR}/env-vars.sh" || true

PREFIX="${CLUSTER_NAME_PREFIX:-mis-demo-cluster}"
ARG="${1-}"  # safe with set -u

# Gather matching clusters into an array (portable: no 'mapfile' dependency)
clusters_raw="$(kind get clusters | grep "^${PREFIX}-" || true)"
clusters=()
while IFS= read -r line; do
  [[ -n "$line" ]] && clusters+=("$line")
done <<< "$clusters_raw"

if (( ${#clusters[@]} == 0 )); then
  echo "No clusters found matching prefix '${PREFIX}-'"
  exit 0
fi

echo "Found clusters:"
for c in "${clusters[@]}"; do
  echo "  - $c"
done
echo

# Fast path: remove all without prompts
if [[ "$ARG" == "--no-prompt" ]]; then
  echo "Deleting ALL clusters with prefix '${PREFIX}-' (no prompt)…"
  for c in "${clusters[@]}"; do
    kind delete cluster --name "$c"
  done
  exit 0
fi

# Default: prompt per cluster (read from the terminal explicitly)
for c in "${clusters[@]}"; do
  ans=""
  read -r -p "Delete cluster '$c'? [y/N] " ans </dev/tty
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    kind delete cluster --name "$c"
    echo "Cluster '$c' removed."
  else
    echo "Skipped '$c'."
  fi
done
