#!/usr/bin/env bash
# =====================================================================
# env-vars.sh
# Centralized configuration for the scripts,
# Source this file from the scripts:
#   source "$(dirname "$0")/env-vars.sh"
# You can override any value by exporting it before sourcing this file.
# =====================================================================

# Export all variables defined below
set -a

# ------------------------------
# General
# ------------------------------
# Namespace that hosts NGINX Ingress Controller (Plus)
NAMESPACE="${NAMESPACE:-nginx-ingress}" #optional
# Helm release name for NGINX Plus IC
RELEASE_NAME="${RELEASE_NAME:-nginx-plus}" #optional

# Namespace for sample app / certificates
APP_NS="${APP_NS:-sandbox}" #optional

# ------------------------------
# NGINX Plus Ingress Controller (F5)
# ------------------------------
NGINX_PLUS_CHART="${NGINX_PLUS_CHART:-oci://ghcr.io/nginx/charts/nginx-ingress}" #optional
# Helm chart version for NIC (this is the CHART version, not your helm client)
NGINX_PLUS_VERSION="${NGINX_PLUS_VERSION:-2.3.0}" #optional

# NGINX Plus controller image repo (private F5 registry)
IMG_REPO="${IMG_REPO:-private-registry.nginx.com/nginx-ic/nginx-plus-ingress}" #optional
# Image pull secret name used by the controller SA
PULL_SECRET_NAME="${PULL_SECRET_NAME:-regcred}" #optional
# License token secret name for runtime (type=nginx.com/license)
LICENSE_SECRET_NAME="${LICENSE_SECRET_NAME:-license-token}" #optional

# Paths to F5 license artifacts (JWT required; CRT/KEY optional here)
# TIP: you can set these to relative paths (e.g., ./creds/nginx-one-eval.jwt)
JWT_FILE="${JWT_FILE:-<PATH-TO>/nginx-one-eval.jwt}" #required
CRT_FILE="${CRT_FILE:-<PATH-TO>/nginx-one-eval.crt}" #required
KEY_FILE="${KEY_FILE:-<PATH-TO>/nginx-one-eval.key}" #required

# ---------------------------------------
# Sample Application (echo) + VirtualServer
# ---------------------------------------
APP_NAME="${APP_NAME:-echo}" #optional
APP_IMAGE="${APP_IMAGE:-ealen/echo-server:latest}" #optional
VS_NAME="${VS_NAME:-demo-vs}" #optional

: "${DNS_BASE_DOMAIN:=svc.cluster.local}" # or your real domain, e.g. example.com #required

# One-time suffix;
: "${DNS_SUFFIX:=$(date +%S%H%M%d%m)}" #optional

# Compose a default FQDN if none provided
# If you want predictable cert names, set DNS_NAME explicitly; otherwise
# the installer will generate one using the format -> suffix + DNS_BASE_DOMAIN .

: "${DNS_NAME:=nginx-${DNS_SUFFIX}.${DNS_BASE_DOMAIN}}" #optional

# ------------------------------
# CyberArk Certificate Manager variables
# ------------------------------
# Namespace for CyberArk Certificate Manager components
CCM_NAMESPACE="${CCM_NAMESPACE:-cyberark}" #optional
# CCM Cloud region: us | eu | apj
CCM_CLOUD_REGION="${CCM_CLOUD_REGION:-us}" #optional
# CyberArk Certificate Manager API Key
CCM_APIKEY="${CCM_APIKEY:-REPLACE_WITH_API_KEY}" #required
# Certificate Manager zone to issue certs from, e.g., "Application\\ZoneName"
CERT_ZONE="${CERT_ZONE:-CloudApps\\Default}" #required

# Service Account created in CCM Registry for pulling images
CCM_REGISTRY_SVC_ACCT_NAME="${CCM_REGISTRY_SVC_ACCT_NAME:-cyberark-nic-test-sa}" #optional
# Team that owns the service account (must exist)
CCM_TEAM_NAME="${CCM_TEAM_NAME:-platform-admin}" #required
# Where to place generated artifacts locally
TMP_ARTIFACTS_DIR="${TMP_ARTIFACTS_DIR:-${HOME}/tmp/nginx-test}" #optional
# Where to persist the generated Kubernetes manifests
CCM_MANIFESTS_FILE="${CCM_MANIFESTS_FILE:-${TMP_ARTIFACTS_DIR}/venafi-manifests.yaml}" #optional

# Stop exporting new variables
set +a
