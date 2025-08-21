#!/usr/bin/env bash
# Copy this as env-vars.sh — config for GCP scripts
# Edit `./env-vars.sh` before running tje scripts.

# ---------- Cloud ----------
export PROJECT_ID="${PROJECT_ID:-REPLACE_WITH_PROJECT_ID}"
export REGION="${REGION:-us-central1}"   # Regional location for GKE and CAS
export ZONE="${ZONE:-}"                  # Optional: for zonal clusters

# ---------- GKE ----------
export CLUSTER_NAME="${CLUSTER_NAME:-gke-dev-01}"
export GKE_RELEASE_CHANNEL="${GKE_RELEASE_CHANNEL:-regular}"  # rapid|regular|stable
export GKE_NODE_COUNT="${GKE_NODE_COUNT:-3}"
export GKE_MACHINE_TYPE="${GKE_MACHINE_TYPE:-e2-standard-4}"

# ---------- Local IP & GKE API allowlist ----------
# Detect your current public IP. Try AWS checkip and fallback to Google DNS (if dig is available),  ifconfig.me.
export LOCAL_IP_CMD='(curl -fsS https://checkip.amazonaws.com || (command -v dig >/dev/null 2>&1 && dig +short TXT o-o.myaddr.l.google.com @ns1.google.com | tr -d "\"") || curl -fsS https://ifconfig.me)'
export LOCAL_IP="${LOCAL_IP:-$(bash -lc "${LOCAL_IP_CMD}" | tr -d "\r\n" | sed 's/^\"//; s/\"$//' )}"

# Comma-separated CIDRs permitted to reach the GKE API server (Master Authorized Networks)
# Default: your current public IP /32. Add more via GKE_API_EXTRA_CIDRS (comma-separated).
export GKE_API_AUTHORIZED_IPS="${GKE_API_AUTHORIZED_IPS:-${LOCAL_IP}/32}"
export GKE_API_EXTRA_CIDRS="${GKE_API_EXTRA_CIDRS:-}"   # e.g., "203.0.113.0/24,198.51.100.10/32"

# ---------- CAS (Google Private CA) ----------
export CAS_POOL="${CAS_POOL:-mis-demo-pool-001}"
export CAS_CA_NAME="${CAS_CA_NAME:-mis-demo-cas--001}"
export CAS_TIER="${CAS_TIER:-devops}"    # enterprise|devops
export DNS_NAME="${DNS_NAME:-example.com}"

# Kubernetes Service Account used for cert request via Workload Identity (e.g., cert-manager issuer)
export CAS_KSA_NAMESPACE="${CAS_KSA_NAMESPACE:-cert-manager}"
export CAS_KSA_NAME="${CAS_KSA_NAME:-google-cas-issuer}"

# Deletion behavior toggles
# Immediately and permanently delete the CA (skip 30-day grace period)
export CAS_SKIP_GRACE_PERIOD="${CAS_SKIP_GRACE_PERIOD:-true}"     # true|false
# If true, pass --ignore-active-certificates to CA delete (use with caution)
export CAS_IGNORE_ACTIVE_CERTS="${CAS_IGNORE_ACTIVE_CERTS:-true}" # true|false
# If true, attempt to revoke then delete ALL issued cert resources before CA deletion
export CAS_DELETE_ISSUED_CERTS="${CAS_DELETE_ISSUED_CERTS:-true}"  # true|false
