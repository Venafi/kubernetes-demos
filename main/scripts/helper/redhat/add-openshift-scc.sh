#!/bin/bash
set -euo pipefail

echo "[INFO] Checking if this is an OpenShift cluster using kubectl..."

if ! command -v kubectl &> /dev/null; then
  echo "[WARN] 'kubectl' not found. Skipping SCC application."
  exit 0
fi

# Detect OpenShift SCC API
if ! kubectl api-resources --api-group=security.openshift.io | grep -q SecurityContextConstraints; then
  echo "[INFO] No SCC API detected. This is not an OpenShift cluster. Skipping."
  exit 0
fi

echo "[INFO] OpenShift SCC API detected. Applying SecurityContextConstraints..."

kubectl apply -f - <<'EOF'
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: privileged-demo-scc
allowHostDirVolumePlugin: true
allowHostIPC: true
allowHostNetwork: true
allowHostPID: true
allowHostPorts: true
allowPrivilegeEscalation: true
allowPrivilegedContainer: true
allowedCapabilities:
- '*'
allowedUnsafeSysctls:
- '*'

defaultAddCapabilities: null
fsGroup:
  type: RunAsAny
groups:
- system:cluster-admins
- system:nodes
- system:masters
priority: 5
readOnlyRootFilesystem: false
requiredDropCapabilities: null
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: RunAsAny
seccompProfiles:
- '*'
supplementalGroups:
  type: RunAsAny
users:
- system:serviceaccount:mesh-apps:adservice
- system:serviceaccount:mesh-apps:cartservice
- system:serviceaccount:mesh-apps:checkoutservice
- system:serviceaccount:mesh-apps:currencyservice
- system:serviceaccount:mesh-apps:emailservice
- system:serviceaccount:mesh-apps:frontend
- system:serviceaccount:mesh-apps:loadgenerator
- system:serviceaccount:mesh-apps:paymentservice
- system:serviceaccount:mesh-apps:productcatalogservice
- system:serviceaccount:mesh-apps:recommendationservice
- system:serviceaccount:mesh-apps:shippingservice
- system:serviceaccount:mesh-apps:default
- system:serviceaccount:sandbox:default
volumes:
- '*'
EOF

echo "[INFO] SecurityContextConstraints successfully applied."
