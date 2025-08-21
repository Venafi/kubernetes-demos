#!/usr/bin/env bash
# cas.sh — create/delete/status Google Certificate Authority Service (Private CA)
# macOS/bash 3.2 friendly: no array expansions; safe under 'set -u'.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/env-vars.sh}"
# shellcheck disable=SC1090
source "${ENV_FILE}"

# Ensure gcloud auth + APIs enabled
"${SCRIPT_DIR}/gcp-login.sh"

# ---------------- Helpers ----------------
loc_flags() {
  # For GKE lookups during WI binding (CAS itself is regional and uses ${REGION})
  if [ -n "${ZONE:-}" ]; then
    printf -- "--zone %s" "${ZONE}"
  elif [ -n "${REGION:-}" ]; then
    printf -- "--region %s" "${REGION}"
  else
    printf ""
  fi
}

_bind_wi() {
  # Best-effort: bind KSA -> GSA for Workload Identity if the cluster exists and WI is enabled.
  local sa="google-cas-issuer@${PROJECT_ID}.iam.gserviceaccount.com"
  local ns="${CAS_KSA_NAMESPACE:-cyberark}"
  local ksa="${CAS_KSA_NAME:-google-cas-issuer}"
  local LF
  LF="$(loc_flags)"

  # Detect WI pool from the cluster; skip if cluster missing or WI not enabled.
  local wip
  if ! wip="$(gcloud container clusters describe "${CLUSTER_NAME}" ${LF} --format="value(workloadIdentityConfig.workloadPool)" 2>/dev/null || true)"; then
    wip=""
  fi
  if [ -z "${wip:-}" ]; then
    echo "NOTE: Skipping WI bind — cluster missing or WI not enabled."
    return 0
  fi

  if ! gcloud iam service-accounts get-iam-policy "${sa}" | grep -q "${PROJECT_ID}\.svc\.id\.goog\[${ns}/${ksa}\]"; then
    gcloud iam service-accounts add-iam-policy-binding "${sa}" \
               --role="roles/iam.workloadIdentityUser" \
               --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${ns}/${ksa}]"
  else
    echo "WI binding already present."
  fi
}

# ---------------- Commands ----------------
create() {
  local pool="${CAS_POOL}" ca="${CAS_CA_NAME}" location="${REGION}" tier="${CAS_TIER}"
  local sa="google-cas-issuer@${PROJECT_ID}.iam.gserviceaccount.com"

  echo "Ensuring CAS pool '${pool}' (tier=${tier})..."
  if ! gcloud privateca pools describe "${pool}" --location "${location}" >/dev/null 2>&1; then
    gcloud privateca pools create "${pool}" --tier "${tier}" --location "${location}"
  else
    echo "CAS pool exists."
  fi

  echo "Ensuring root CA '${ca}' in pool '${pool}'..."
  if ! gcloud privateca roots describe "${ca}" --pool "${pool}" --location "${location}" >/dev/null 2>&1; then
    gcloud privateca roots create "${ca}" \
           --pool "${pool}" \
           --auto-enable \
           --subject "CN=${DNS_NAME}, O=Platform, OU=MIS, C=US, ST=MA, L=Newton" \
           --max-chain-length 2 \
           --location "${location}"
  else
    echo "Root CA exists."
  fi

  echo "Ensuring service account '${sa}'..."
  if ! gcloud iam service-accounts describe "${sa}" >/dev/null 2>&1; then
    gcloud iam service-accounts create google-cas-issuer
  else
    echo "Service account exists."
  fi

  echo "Ensuring pool IAM binding for certificate requests..."
  if ! gcloud privateca pools get-iam-policy "${pool}" --location "${location}" | grep -q "serviceAccount:${sa}"; then
    gcloud privateca pools add-iam-policy-binding "${pool}" \
           --location "${location}" \
           --role "roles/privateca.certificateRequester" \
           --member "serviceAccount:${sa}"
  else
    echo "Pool binding already present."
  fi

  echo "Best-effort WI binding to KSA ${CAS_KSA_NAMESPACE:-cyberark}/${CAS_KSA_NAME:-google-cas-issuer}..."
  _bind_wi || true
}

_delete_issued_certs() {
  # Revokes and deletes all certificates issued by the specified CA (best-effort).
  local pool="${1}" ca="${2}" location="${3}"
  echo "Revoking and deleting issued certificates for CA '${ca}' in pool '${pool}' (location '${location}')..."
  local project_number
  project_number="$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")"

  local issuer="projects/${project_number}/locations/${location}/caPools/${pool}/certificateAuthorities/${ca}"
  # List returns fully-qualified names by default when using --format=value(name)
  local certs
  certs="$(gcloud privateca certificates list --issuer-pool="${pool}" --location="${location}" --filter="issuer_certificate_authority=${issuer}" --format="value(name)" || true)"
  if [ -z "${certs}" ]; then
    echo "No issued certificates found for this CA."
    return 0
  fi

  # Revoke then delete each certificate resource
  IFS=$'\n'
  for CERT in ${certs}; do
    [ -z "${CERT}" ] && continue
    echo "Revoking certificate: ${CERT}"
    gcloud privateca certificates revoke \
           --certificate "${CERT}" \
           --issuer-pool "${pool}" \
           --issuer-location "${location}" \
           --quiet || true

    echo "Deleting certificate: ${CERT}"
    gcloud privateca certificates delete \
           --certificate "${CERT}" \
           --issuer-pool "${pool}" \
           --issuer-location "${location}" \
           --quiet || true
  done
  unset IFS
}

delete() {
  local pool="${CAS_POOL}" ca="${CAS_CA_NAME}" location="${REGION}"
  local sa="google-cas-issuer@${PROJECT_ID}.iam.gserviceaccount.com"

  # Optional: try to clean up issued certs first
  if [ "${CAS_DELETE_ISSUED_CERTS:-true}" = "true" ]; then
    _delete_issued_certs "${pool}" "${ca}" "${location}" || true
  fi

  echo "Disabling root CA '${ca}' (if exists)..."
  gcloud privateca roots disable "${ca}" --pool "${pool}" --location "${location}" --quiet || true

  echo "Removing IAM bindings (best-effort)..."
  gcloud iam service-accounts remove-iam-policy-binding "${sa}" \
         --role "roles/iam.workloadIdentityUser" \
         --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${CAS_KSA_NAMESPACE:-cyberark}/${CAS_KSA_NAME:-google-cas-issuer}]" || true
  gcloud privateca pools remove-iam-policy-binding "${pool}" \
         --location "${location}" \
         --role "roles/privateca.certificateRequester" \
         --member "serviceAccount:${sa}" || true

  echo "Deleting root CA '${ca}'..."
  EXTRA_FLAGS=""
  [ "${CAS_SKIP_GRACE_PERIOD:-false}" = "true" ] && EXTRA_FLAGS="${EXTRA_FLAGS} --skip-grace-period"
  [ "${CAS_IGNORE_ACTIVE_CERTS:-false}" = "true" ] && EXTRA_FLAGS="${EXTRA_FLAGS} --ignore-active-certificates"
  # shellcheck disable=SC2086
  gcloud privateca roots delete "${ca}" --pool "${pool}" --location "${location}" --quiet ${EXTRA_FLAGS} || true

  echo "Deleting pool '${pool}'..."
  gcloud privateca pools delete "${pool}" --location "${location}" --quiet || true

  echo "Deleting service account '${sa}'..."
  gcloud iam service-accounts delete "${sa}" --quiet || true
}

status() {
  gcloud privateca pools list --location "${REGION}" --format="table(name,location,tier)"
  echo
  gcloud privateca roots list --pool "${CAS_POOL}" --location "${REGION}" --format="table(name,state)"
}

case "${1:-}" in
  create) create ;;
  delete) delete ;;
  status) status ;;
  *)
    cat <<EOF
Usage: $0 {create|delete|status}

Env toggles for deletion:
  CAS_DELETE_ISSUED_CERTS=true|false   # default true; revoke+delete issued certs first
  CAS_SKIP_GRACE_PERIOD=true|false     # default false; if true, immediately delete CA (skip 30-day grace)
  CAS_IGNORE_ACTIVE_CERTS=true|false   # default false; add only if you want to force-delete with active certs

Examples:
  CAS_DELETE_ISSUED_CERTS=true CAS_SKIP_GRACE_PERIOD=true ./cas.sh delete
EOF
    exit 2
    ;;
esac
