#!/bin/bash

set -euo pipefail

echo "[deploy-public-gateway] Deploying public-facing Gateway with DNS and TLS..."

: "${AWS_ZONE_ID:?AWS_ZONE_ID is required}"
: "${AWS_PROFILE:?AWS_PROFILE is required}"
: "${RESOURCE_SUFFIX:?RESOURCE_SUFFIX is required}"
: "${DOMAIN_NAME:?DOMAIN_NAME is required}"
: "${CYBR_ZONE_PUBLIC_CA:?CYBR_ZONE_PUBLIC_CA is required}"

# Override suffix if resource file exists
SUFFIX_FILE="${ARTIFACTS_DIR}/resource-suffix.txt"
if [ -f "$SUFFIX_FILE" ]; then
  RESOURCE_SUFFIX="$(<"$SUFFIX_FILE")"
  echo "Overriding RESOURCE_SUFFIX with value from file: $RESOURCE_SUFFIX"
fi

CERT_NAME="${RESOURCE_SUFFIX}.${DOMAIN_NAME}"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect environment

IS_KIND=$(kubectl config current-context 2>/dev/null | grep -q '^kind-' && echo "true" || echo "false")
EC2_TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 1" --connect-timeout 1 || true)

if [[ -n "$EC2_TOKEN" ]]; then
  IS_EC2="true"
else
  IS_EC2=$(curl -s --connect-timeout 1 http://169.254.169.254/latest/meta-data/ > /dev/null && echo "true" || echo "false")
fi

# Skip only if kind AND NOT on EC2. EC2 is also running kind but we'll use the EC2 IP to access the service.
if [[ "$IS_KIND" == "true" && "$IS_EC2" == "false" ]]; then
  echo "[deploy-public-gateway] Detected local kind cluster (not EC2). Skipping public gateway deployment."
  exit 0
fi

# Validate AWS credentials only outside EC2
if [[ "$IS_EC2" == "false" ]]; then
  echo "[deploy-public-gateway] Validating AWS credentials for profile '$AWS_PROFILE'..."
  if ! aws sts get-caller-identity --profile "$AWS_PROFILE" >/dev/null 2>&1; then
    echo "[deploy-public-gateway] ❌ AWS authentication failed for profile '$AWS_PROFILE'."
    exit 1
  fi
fi

echo "[deploy-public-gateway] Authenticated to AWS - Will attempt to create Route53 entries"
# Retrieve EC2 public IP for fallback
if [[ "$IS_EC2" == "true" ]]; then
  EC2_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
  if [[ -n "$EC2_TOKEN" ]]; then
    EC2_IP=$(curl -s -H "X-aws-ec2-metadata-token: $EC2_TOKEN" \
      http://169.254.169.254/latest/meta-data/public-ipv4 || true)
  else
    EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || true)
  fi
fi

INGRESS_HOSTNAME=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

if [[ -n "$INGRESS_HOSTNAME" ]]; then
  DNS_TARGET="$INGRESS_HOSTNAME"
elif [[ -n "$INGRESS_IP" ]]; then
  DNS_TARGET="$INGRESS_IP"
else
  DNS_TARGET="$EC2_IP"
fi

# Run DNS mapping with EC2_IP fallback if needed
set +e
"$SCRIPTS_DIR/helper/aws/map-dns-to-gateway.sh" "$AWS_ZONE_ID" "$CERT_NAME" "$AWS_PROFILE" "$DNS_TARGET"
DNS_EXIT_CODE=$?
set -e

# Create VenafiClusterIssuer
echo "[deploy-public-gateway] Creating VenafiClusterIssuer..."
cat <<EOF | kubectl apply -f -
apiVersion: jetstack.io/v1alpha1
kind: VenafiClusterIssuer
metadata:
  name: venafi-publicca-cluster-issuer
spec:
  venafiConnectionName: venafi-connection
  zone: ${CYBR_ZONE_PUBLIC_CA}
EOF

kubectl wait venaficlusterissuer venafi-publicca-cluster-issuer \
  --for=condition=Ready=True --timeout=60s || {
    echo "[ERROR] VenafiClusterIssuer did not become Ready in time."
    exit 1
}

# Create Certificate
echo "[deploy-public-gateway] Creating Certificate..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${CERT_NAME}
  namespace: istio-system
spec:
  secretName: ${CERT_NAME}
  duration: 72h
  privateKey:
    rotationPolicy: Always
  subject:
    organizations: ["CyberArk Inc"]
    organizationalUnits: ["MIS Demo"]
    localities: ["Newton"]
    provinces: ["MA"]
    countries: ["US"]
  dnsNames: ["${CERT_NAME}"]
  commonName: "${CERT_NAME}"
  issuerRef:
    name: venafi-publicca-cluster-issuer
    kind: VenafiClusterIssuer
    group: jetstack.io
EOF

kubectl wait certificate "${CERT_NAME}" -n istio-system \
  --for=condition=Ready=True --timeout=90s

# Create Gateway and VirtualService
echo "[deploy-public-gateway] Creating Gateway and routes..."
cat <<EOF | kubectl -n mesh-apps apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: storefront-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https-default
      protocol: HTTPS
    tls:
      mode: SIMPLE
      serverCertificate: sds
      privateKey: sds
      credentialName: "${CERT_NAME}"
    hosts:
    - "${CERT_NAME}"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: storefront-virtualservice
spec:
  hosts:
  - "${CERT_NAME}"
  gateways:
  - storefront-gateway
  http:
  - route:
    - destination:
        host: frontend
        port:
          number: 80
---
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: allow-egress-googleapis
spec:
  hosts:
  - "accounts.google.com" # Used to get token
  - "*.googleapis.com"
  ports:
  - number: 80
    protocol: HTTP
    name: http
  - number: 443
    protocol: HTTPS
    name: https
---
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: allow-egress-google-metadata
spec:
  hosts:
  - metadata.google.internal
  addresses:
  - 169.254.169.254 # GCE metadata server
  ports:
  - number: 80
    name: http
    protocol: HTTP
  - number: 443
    name: https
    protocol: HTTPS
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend
spec:
  hosts:
  - "frontend.mesh-apps.svc.cluster.local"
  http:
  - route:
    - destination:
        host: frontend
        port:
          number: 80
EOF

# Show summary
echo ""
echo "🔎 Verifying created resources..."
kubectl get certificate "${CERT_NAME}" -n istio-system
kubectl get secret "${CERT_NAME}" -n istio-system
kubectl get gateway storefront-gateway -n mesh-apps

echo ""
echo "🚀 What's next:"
if [[ "$DNS_EXIT_CODE" -eq 2 && -f /tmp/map-dns-cmd.sh ]]; then
  echo ""
  echo "⚠️ DNS was not applied automatically (EC2 fallback mode)."
  echo "🛠️ To apply the DNS record manually, run:"
  echo ""
  cat /tmp/map-dns-cmd.sh
  echo ""
fi
echo "→ Open the application in your browser:"
echo "   https://${CERT_NAME}"
echo ""
echo "💡 Tip: You can verify the certificate:"
echo "   kubectl describe certificate ${CERT_NAME} -n istio-system"
echo ""
echo "📡 Gateway status:"
kubectl get virtualservice storefront-virtualservice -n mesh-apps
