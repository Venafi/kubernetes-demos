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
priority: 5
allowHostPorts: false
allowHostPID: false
allowHostNetwork: false
allowHostDirVolumePlugin: true
readOnlyRootFilesystem: false
allowPrivilegeEscalation: true
allowPrivilegedContainer: true
allowedUnsafeSysctls: null
allowHostIPC: false
allowedCapabilities:
  - '*'
defaultAddCapabilities: null
requiredDropCapabilities: null
seccompProfiles:
  - '*'
seLinuxContext:
  type: MustRunAs
runAsUser:
  type: RunAsAny
fsGroup:
  type: MustRunAs
supplementalGroups:
  type: MustRunAs
groups: []  
volumes:
- '*'
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
- system:serviceaccount:sandbox:default
EOF

echo "[INFO] SecurityContextConstraints successfully applied."
