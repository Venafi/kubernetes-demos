#!/usr/bin/env bash
set -euo pipefail

#Set it the namespace where you have cyberark components installed
CCM_NAMESPACE=cyberark
CCM_APIKEY=REPLACE_WITH_API_KEY
CERT_ZONE=CloudApps\\Default
# ------------------------------
# CyberArk API key secret
# ------------------------------
echo ">> Creating cyberark-cert-mgr-creds Secret in ${CCM_NAMESPACE}"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cyberark-cert-mgr-creds
  namespace: ${CCM_NAMESPACE}
stringData:
  cyberark-cert-mgr-api-key: ${CCM_APIKEY}
EOF


echo ">> Creating VenafiConnection in ${CCM_NAMESPACE}"
kubectl apply -f - <<EOF
apiVersion: jetstack.io/v1alpha1
kind: VenafiConnection
metadata:
  name: cyberark-saas-connection
  namespace: ${CCM_NAMESPACE}
spec:
  vaas:
    url: https://api.venafi.cloud
    apiKey:
    - secret:
        name: cyberark-cert-mgr-creds
        fields: ["cyberark-cert-mgr-api-key"]
EOF

# ------------------------------
# RBAC for reading the API key Secret
# ------------------------------
echo ">> Applying RBAC so only Cyberark components can read cyberark-cert-mgr-creds"
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: read-ccm-credentials
  namespace: ${CCM_NAMESPACE}
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["cyberark-cert-mgr-creds"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-ccm-credentials
  namespace: ${CCM_NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: read-ccm-credentials
subjects:
- kind: ServiceAccount
  name: venafi-connection
  namespace: ${CCM_NAMESPACE}
EOF

echo ">> Creating VenafiClusterIssuer (cluster-wide)"
kubectl apply -f - <<EOF
apiVersion: jetstack.io/v1alpha1
kind: VenafiClusterIssuer
metadata:
  name: cyberark-cert-mgr-cluster-issuer
spec:
  venafiConnectionName: cyberark-saas-connection
  zone: ${CERT_ZONE}
EOF


