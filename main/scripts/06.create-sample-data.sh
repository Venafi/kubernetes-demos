#!/bin/bash

set -euo pipefail

echo "[create-sample-data] Starting sample certificate and workload setup..."

# Validate required env vars
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR is required}"

# Create root and client directories
echo "[create-sample-data] Initializing directory structure under ${ARTIFACTS_DIR}"
rm -rf "${ARTIFACTS_DIR}/root" "${ARTIFACTS_DIR}/client"
mkdir -p "${ARTIFACTS_DIR}/root" "${ARTIFACTS_DIR}/client"
touch "${ARTIFACTS_DIR}/root/index"
echo 01 > "${ARTIFACTS_DIR}/root/serial.txt"

# Copy configs
cp templates/certs/root-certificate.config "${ARTIFACTS_DIR}/root/root-certificate.config"
sed "s|REPLACE_WITH_ARTIFACTS_DIR|${ARTIFACTS_DIR}|g" templates/certs/root-csr.config > "${ARTIFACTS_DIR}/root/root-csr.config"
cp templates/certs/client-certificate.config "${ARTIFACTS_DIR}/client/client-certificate.config"
cp templates/certs/client-csr.config "${ARTIFACTS_DIR}/client/client-csr.config"

# Create phantom CA
echo "[create-sample-data] Creating phantom Root CA..."
openssl genrsa -out "${ARTIFACTS_DIR}/root/rootCA.key" 4096
openssl req -new -key "${ARTIFACTS_DIR}/root/rootCA.key" \
  -out "${ARTIFACTS_DIR}/root/rootCA.csr" -nodes \
  -config "${ARTIFACTS_DIR}/root/root-certificate.config"

openssl ca -batch -notext \
  -out "${ARTIFACTS_DIR}/root/rootCA.pem" \
  -keyfile "${ARTIFACTS_DIR}/root/rootCA.key" \
  -selfsign -days 180 \
  -config "${ARTIFACTS_DIR}/root/root-csr.config" \
  -in "${ARTIFACTS_DIR}/root/rootCA.csr" \
  -subj "/C=US/ST=MA/L=Newton/O=MIS Lab/OU=Platform Engineering/CN=Phantom RSA CA"

kubectl -n sandbox create secret tls phantom-ca \
  --key="${ARTIFACTS_DIR}/root/rootCA.key" \
  --cert="${ARTIFACTS_DIR}/root/rootCA.pem" \
  --dry-run=client -o yaml | kubectl apply -f -

# Issue client certificate using phantom CA
create_client_certificate() {
  local cert_name="$1"
  local dir="${ARTIFACTS_DIR}/client"

  echo "[create-sample-data] Creating client cert: ${cert_name}"
  openssl genrsa -out "${dir}/${cert_name}.key" 2048
  openssl req -new -sha512 -nodes \
    -key "${dir}/${cert_name}.key" \
    -out "${dir}/${cert_name}.csr" \
    -config "${dir}/client-csr.config" \
    -subj "/C=US/ST=MA/L=Newton/O=CyberArk/OU=cyberark-unit/CN=${cert_name}"

  openssl x509 -req -sha512 -days 91 \
    -in "${dir}/${cert_name}.csr" \
    -CA "${ARTIFACTS_DIR}/root/rootCA.pem" \
    -CAkey "${ARTIFACTS_DIR}/root/rootCA.key" \
    -CAcreateserial \
    -out "${dir}/${cert_name}.pem" \
    -extfile "${dir}/client-certificate.config"

  kubectl -n sandbox create secret tls "${cert_name}" \
    --key="${dir}/${cert_name}.key" \
    --cert="${dir}/${cert_name}.pem" \
    --dry-run=client -o yaml | kubectl apply -f -
}

# Unmanaged and self-signed certs
create_client_certificate "unmanaged-kid.svc.cluster.local"

openssl req -x509 -nodes -days 91 -newkey rsa:1024 \
  -keyout "${ARTIFACTS_DIR}/client/cipher-snake.svc.cluster.local.key" \
  -out "${ARTIFACTS_DIR}/client/cipher-snake.svc.cluster.local.pem" \
  -subj "/C=US/ST=MA/L=Newton/O=CyberArk/OU=cyberark-unit/CN=cipher-snake.svc.cluster.local"

kubectl -n sandbox create secret tls cipher-snake.svc.cluster.local \
  --key="${ARTIFACTS_DIR}/client/cipher-snake.svc.cluster.local.key" \
  --cert="${ARTIFACTS_DIR}/client/cipher-snake.svc.cluster.local.pem" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create certificates with VenafiClusterIssuer
create_certificate_resource() {
  local prefix="$1"
  local duration="$2"

  echo "[create-sample-data] Creating managed certificate: ${prefix}"
  cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${prefix}.svc.cluster.local
  namespace: sandbox
spec:
  secretName: ${prefix}.svc.cluster.local
  duration: ${duration}
  subject:
    organizations: ["CyberArk Inc"]
    organizationalUnits: ["MIS Demo"]
    localities: ["Newton"]
    provinces: ["MA"]
    countries: ["US"]
  privateKey:
    rotationPolicy: Always
  dnsNames: ["${prefix}.svc.cluster.local"]
  commonName: ${prefix}.svc.cluster.local
  issuerRef:
    name: venafi-privateca-cluster-issuer
    kind: VenafiClusterIssuer
    group: jetstack.io
EOF

  kubectl wait certificate "${prefix}.svc.cluster.local" -n sandbox \
    --for=condition=Ready=True --timeout=90s
}

create_certificate_resource "expiry-eddie" "8760h"
create_certificate_resource "ghost-rider" "2400h"

# NGINX workloads with mounted certs
create_nginx_workload() {
  local prefix="$1"

  echo "[create-sample-data] Creating nginx workload: ${prefix}"
  cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: Service
metadata:
  name: ${prefix}-nginx
  namespace: sandbox
spec:
  type: NodePort
  ports:
    - port: 80
  selector:
    app: ${prefix}-nginx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${prefix}-nginx
  namespace: sandbox
  labels:
    app: ${prefix}-nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${prefix}-nginx
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: ${prefix}-nginx
    spec:
      containers:
        - name: ${prefix}-nginx
          image: nginx:latest
          ports:
            - containerPort: 80
          volumeMounts:
            - mountPath: "/etc/${prefix}-nginx/ssl"
              name: tls
              readOnly: true
      volumes:
        - name: tls
          secret:
            secretName: ${prefix}.svc.cluster.local
EOF
}

create_nginx_workload "expiry-eddie"
create_nginx_workload "unmanaged-kid"
create_nginx_workload "cipher-snake"

# Final validation
echo "[create-sample-data] Validating resources..."
kubectl get certificates -n sandbox
kubectl get secrets -n sandbox
kubectl get deployments -n sandbox
kubectl get services -n sandbox

echo ""
echo "[create-sample-data] Sample workloads and certificates created ✅"
echo "Access CyberArk Certificate Manager UI and review Installations->Kubernetes Clusters for insights. It may take a few minutes"
