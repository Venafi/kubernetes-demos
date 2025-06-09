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
    echo "For e.g: Replace <app-label> with frontend"
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

port_forward_service() {
  local name="$1"
  local namespace="$2"
  local service="$3"
  local target_port="$4"
  local local_port="$5"
  local pidfile="/tmp/port-forward-${name}.pid"

  if port_in_use $local_port; then
    echo "[${name}] ERROR: Port $local_port is already in use."
    exit 1
  fi

  if curl -s --connect-timeout 1 http://169.254.169.254/latest/meta-data/ > /dev/null; then
    echo "[${name}] Running on EC2 — launching port-forward for ${service}..."
    kubectl -n "$namespace" port-forward svc/"$service" ${local_port}:${target_port} --address=127.0.0.1 &
    echo $! > "$pidfile"
    echo "[${name}] Port-forward running with PID $(cat "$pidfile")"
    TOKEN=$(curl -s -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" http://169.254.169.254/latest/api/token || true)
    if [ -n "$TOKEN" ]; then
      EC2_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
    else
      EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "<unknown-ec2-ip>")
    fi
    echo ""
    echo "[${name}] From your laptop, run:"
    echo "  ssh -i <your-key.pem> -L ${local_port}:localhost:${local_port} ubuntu@${EC2_IP}"
    echo "Then open: http://localhost:${local_port}"
  else
    echo "[${name}] Running locally — launching port-forward for ${service}..."
    kubectl -n "$namespace" port-forward svc/"$service" ${local_port}:${target_port} --address=127.0.0.1 &
    echo $! > "$pidfile"
    echo "[${name}] Port-forward running with PID $(cat "$pidfile")"
    echo "[${name}] Open: http://localhost:${local_port}"
  fi
}

# Port-forward to access frontend app in background
app-url() {
  port_forward_service "app-url" "mesh-apps" "frontend" 80 8120
}

# Port-forward to access Kiali dashboard in background
kiali-url() {
  port_forward_service "kiali-url" "istio-system" "kiali" 20001 20001
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
