#!/bin/bash

set -euo pipefail

echo "[show] Show resources"

# Function to check if a port is already in use
port_in_use() {
  local port=$1
  lsof -i ":$port" >/dev/null 2>&1
}

# Issuers inspection with improved JSON parsing
issuers() {
  echo "[issuers] Listing all issuers"
  kubectl get ClusterIssuer,Issuer,VenafiClusterIssuer,VenafiIssuer,issuers.firefly.venafi.com \
    --all-namespaces \
    -o json | jq -r '.items[] | [.metadata.namespace // "cluster", .metadata.name, .kind, (.status.conditions[]?.type // "N/A")] | @tsv' | \
    column -t -s $'\t'
}

# CertificateRequestPolicy listing
policies() {
  echo "[policies] Listing CertificateRequestPolicy resources"
  kubectl get CertificateRequestPolicy
}

# TLS Secret listing
secrets() {
  echo "[secrets] Listing TLS secrets"
  kubectl get secrets --field-selector type=kubernetes.io/tls \
    --all-namespaces \
    -o=custom-columns='NAMESPACE:metadata.namespace','NAME:metadata.name'
}

# SPIFFE SVID inspection from Istio, takes app label as argument
svid() {
  if [ $# -lt 1 ]; then
    echo "[svid] ERROR: Requires an app label"
    echo "Usage: $0 svid <app-label>"
    exit 1
  fi
  local app_label="$1"
  pods=$(kubectl get pods -n mesh-apps -l app="${app_label}" -o jsonpath='{.items[*].metadata.name}')
  count=$(echo "$pods" | wc -w)

  if [ "$count" -eq 0 ]; then
    echo "[svid] ERROR: No pods found for app=${app_label}"
    exit 1
  fi

  PODNAME=$(echo "$pods" | awk '{print $1}')
  echo "[svid] Using pod: $PODNAME"

  istioctl -n mesh-apps proxy-config secret "$PODNAME" \
    -o json | jq -r '.dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes' | \
    base64 --decode | openssl x509 -text -noout
}

# Port-forward to access frontend app in background
app-url() {
  if port_in_use 8120; then
    echo "[app-url] ERROR: Port 8120 is already in use."
    exit 1
  fi
  echo "[app-url] Access the swag shop via http://localhost:8120"
  kubectl -n mesh-apps port-forward service/frontend 8120:80 &
  echo $! > /tmp/port-forward-frontend.pid
  echo "[app-url] Port-forward running in background with PID $(cat /tmp/port-forward-frontend.pid)"
}

# Port-forward to access Kiali dashboard in background
kiali-url() {
  if port_in_use 20001; then
    echo "[kiali-url] ERROR: Port 20001 is already in use."
    exit 1
  fi
  echo "[kiali-url] Access the Kiali dashboard via http://localhost:20001"
  kubectl port-forward svc/kiali 20001:20001 -n istio-system &
  echo $! > /tmp/port-forward-kiali.pid
  echo "[kiali-url] Port-forward running in background with PID $(cat /tmp/port-forward-kiali.pid)"
}

# Stop background port-forward processes
stop-port-forwards() {
  for pidfile in /tmp/port-forward-*.pid; do
    if [ -f "$pidfile" ]; then
      pid=$(cat "$pidfile")
      echo "[stop-port-forwards] Killing PID $pid from $pidfile"
      kill "$pid" && rm -f "$pidfile"
    fi
  done
}

# Help
show_usage() {
  echo "Usage: $0 <function-name> [args...]"
  echo "Available functions:"
  declare -F | awk '{print "  " $3}' | grep -v "^show_usage$"
}

# Execute selected function(s)
if [ $# -eq 0 ]; then
  show_usage
  exit 1
fi

fn="$1"
shift

if declare -f "$fn" > /dev/null; then
  echo "[show] Executing: $fn $*"
  "$fn" "$@"
else
  echo "[show] ERROR: function '$fn' not found"
  show_usage
  exit 1
fi

echo "[show] Complete"
