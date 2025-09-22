#!/usr/bin/env bash
set -euo pipefail

BOLD="\033[1m"; RESET="\033[0m"; YEL="\033[33m"; GRN="\033[32m"; RED="\033[31m"

# --- Load env file if present ---
ENV_FILE="${1:-./env-vars.sh}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
else
  echo -e "${YEL}No env file found at '${ENV_FILE}'. Proceeding with interactive prompts (where needed).${RESET}"
fi

require_cmd(){ command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}Missing dependency:${RESET} $1"; exit 1; }; }
require_cmd vault
require_cmd jq
require_cmd curl

prompt_if_unset(){
  local var="$1" prompt="$2"
  if [[ -z "${!var:-}" ]]; then
    if [[ -t 0 ]]; then
      read -rp "$(echo -e "${BOLD}${prompt}${RESET} ")" "$var"
      export "$var"
    else
      echo -e "${RED}Error:${RESET} $var not set and no TTY for prompts. Set it in ${ENV_FILE}."
      exit 1
    fi
  fi
}

# --- Required: Vault endpoint + token ---
prompt_if_unset "VAULT_ADDR"   "Enter VAULT_ADDR (e.g., https://vault.example.com:8200):"
prompt_if_unset "VAULT_TOKEN"  "Enter VAULT_TOKEN (admin/root token):"

# Optional TLS for CLI
export VAULT_CACERT="${VAULT_CACERT:-}"
export VAULT_SKIP_VERIFY="${VAULT_SKIP_VERIFY:-}"

# --- Vault objects / identity config ---
prompt_if_unset "ROLE_NAME"            "Enter role name (e.g., SecretsHubHashiVaultRole):"
prompt_if_unset "JWT_PATH"             "Enter JWT auth mount path (e.g., jwt):"
prompt_if_unset "MOUNT_PATH"           "Enter KV v2 mount path (e.g., my-secrets):"
prompt_if_unset "OIDC_DISCOVERY_URL"   "Enter OIDC discovery BASE URL (no /.well-known, e.g., https://aapXXXX.id.cyberark.cloud/__idaptive_cybr_user_oidc):"

POLICY_NAME="${POLICY_NAME:-SecretsHubHashiVaultRolePolicy}"
OIDC_AUDIENCE="${OIDC_AUDIENCE:-SecretsHub}"
SUBJECT="${SUBJECT:-SECRETS_HUB_HASHI_IDENTITY_APPLICATION_USER}"
TOKEN_TTL="${TOKEN_TTL:-3600}"
OIDC_DISCOVERY_CA_PEM="${OIDC_DISCOVERY_CA_PEM:-}"
OIDC_ISSUER="${OIDC_ISSUER:-}"

echo ""
echo -e "${BOLD}Vault address:${RESET} ${VAULT_ADDR}"
echo -e "${BOLD}Mount path:${RESET} ${MOUNT_PATH}"
echo -e "${BOLD}Role name:${RESET} ${ROLE_NAME}"
echo -e "${BOLD}Auth (JWT) path:${RESET} ${JWT_PATH}"
echo -e "${BOLD}Discovery base:${RESET} ${OIDC_DISCOVERY_URL}"
echo ""

# --- Resolve issuer exactly ---
base_disc="${OIDC_DISCOVERY_URL%%/.well-known/*}"     # strip accidental suffix
disc_url="${base_disc%/}/.well-known/openid-configuration"
issuer="${OIDC_ISSUER}"
if [[ -z "$issuer" ]]; then
  issuer="$(curl -sS "${disc_url}" | jq -r '.issuer')"
  if [[ -z "$issuer" || "$issuer" == "null" ]]; then
    echo -e "${RED}Failed to resolve issuer from ${disc_url}${RESET}"; exit 1
  fi
fi

# --- Sanity: reachability of Vault ---
if ! vault status -address="${VAULT_ADDR}" >/dev/null 2>&1; then
  echo -e "${YEL}Warning:${RESET} 'vault status' failed; verify VAULT_ADDR/VAULT_CACERT/VAULT_SKIP_VERIFY and token."
fi

# --- Policy (create or override) ---
if vault policy read -address="${VAULT_ADDR}" "${POLICY_NAME}" >/dev/null 2>&1; then
  echo -e "${YEL}Policy '${POLICY_NAME}' exists; it will be overwritten.${RESET}"
fi
vault policy write -address="${VAULT_ADDR}" "${POLICY_NAME}" - <<EOF
path "${MOUNT_PATH}/data/*" {
  capabilities = ["read", "list", "create", "update", "delete"]
}
path "${MOUNT_PATH}/metadata/*" {
  capabilities = ["read", "list", "update"]
}
path "sys/mounts/${MOUNT_PATH}/*" {
  capabilities = ["read"]
}
EOF
echo -e "✅ ${GRN}Policy ready:${RESET} ${POLICY_NAME}"

# --- Enable JWT auth backend ---
if ! vault auth list -address="${VAULT_ADDR}" | grep -q "^${JWT_PATH}/"; then
  vault auth enable -address="${VAULT_ADDR}" -path="${JWT_PATH}" jwt >/dev/null
  echo -e "✅ ${GRN}Enabled auth/${JWT_PATH}${RESET}"
else
  echo -e "ℹ️  auth/${JWT_PATH} already enabled"
fi

# --- Configure JWT backend ---
cfg_args=( oidc_discovery_url="${base_disc}" bound_issuer="${issuer}" )
if [[ -n "${OIDC_DISCOVERY_CA_PEM}" ]]; then
  [[ -r "${OIDC_DISCOVERY_CA_PEM}" ]] || { echo -e "${RED}Not readable:${RESET} ${OIDC_DISCOVERY_CA_PEM}"; exit 1; }
  cfg_args+=( oidc_discovery_ca_pem=@"${OIDC_DISCOVERY_CA_PEM}" )
fi
vault write -address="${VAULT_ADDR}" "auth/${JWT_PATH}/config" "${cfg_args[@]}" >/dev/null
echo -e "✅ ${GRN}Configured auth/${JWT_PATH}${RESET} (discovery='${base_disc}', issuer='${issuer}')" 

# --- Create/override role ---
role_body=$(cat <<JSON
{
  "role_type": "jwt",
  "user_claim": "sub",
  "bound_audiences": ["${OIDC_AUDIENCE}"],
  "token_policies": ["${POLICY_NAME}"],
  "token_ttl": ${TOKEN_TTL},
  "bound_claims": { "sub": ["${SUBJECT}"] }
}
JSON
)
echo "${role_body}" | vault write -address="${VAULT_ADDR}" "auth/${JWT_PATH}/role/${ROLE_NAME}" - >/dev/null
echo -e "✅ ${GRN}Role ready:${RESET} ${ROLE_NAME}"

# --- Create sample secrets  ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "${SCRIPT_DIR}/create-sample-secrets.sh" ]]; then
  "${SCRIPT_DIR}/create-sample-secrets.sh" "${ENV_FILE}" || echo "⚠️ sample secret creation reported issues."
else
  echo "ℹ️  Skipping sample secrets: create-sample-secrets.sh not found/executable"
fi

# --- Summary ---
echo ""
echo -e "${BOLD}Setup complete for CyberArk Secrets Hub access${RESET}"
echo -e "${BOLD}Vault address:${RESET} ${VAULT_ADDR}"
echo -e "${BOLD}Mount path:${RESET} ${MOUNT_PATH}"
echo -e "${BOLD}Role name:${RESET} ${ROLE_NAME}"
echo -e "${BOLD}Authentication path:${RESET} ${JWT_PATH}"
echo -e "${BOLD}Issuer (exact):${RESET} ${issuer}"
