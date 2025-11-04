#!/usr/bin/env bash
set -euo pipefail

APP_NS="sandbox"
APP_NAME="echo"
VS_DNSNAME="foo.svc.cluster.local"
ISSUER_NAME=cyberark-cert-mgr-cluster-issuer
ISSUER_KIND=VenafiClusterIssuer
ISSUER_GROUP=jetstack.io

# ================================
# Virtual Server with cert-manager enterprise issuer VenafiClusterIssuer 
# ================================
echo ">> Creating VirtualServer my-virtual-server (host: ${VS_DNSNAME}, cluster-issuer: ${ISSUER_NAME})"
cat <<EOF | kubectl apply -f -
apiVersion: k8s.nginx.org/v1
kind: VirtualServer
metadata:
  name: my-virtual-server
  namespace: ${APP_NS}
spec:
  host: ${VS_DNSNAME}
  tls:
    secret: ${VS_DNSNAME}
    cert-manager:
      issuer: ${ISSUER_NAME}
      issuer-kind: ${ISSUER_KIND}
      issuer-group: ${ISSUER_GROUP}
      common-name: ${VS_DNSNAME}
      duration: 720h
      renew-before: 480h
      usages: digital signature,server auth,client auth  
  upstreams:
  - name: ${APP_NAME}-svc
    service: ${APP_NAME}
    port: 80
  routes:
  - path: /
    action:
      pass: ${APP_NAME}-svc
EOF