#!/usr/bin/env bash
set -euo pipefail

# Detect if the current Kubernetes cluster is OpenShift.
# Return 0 if OpenShift, 1 otherwise.

if kubectl api-resources | grep -q '\.openshift.io'; then
  exit 0
else
  exit 1
fi
