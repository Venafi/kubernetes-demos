#!/usr/bin/env bash
set -euo pipefail

# create-sample-secrets.sh [env-file]
# Ensures KV v2 at $MOUNT_PATH, then writes NUM_SECRETS random entries under app1/ and app2/.
# If NUM_SECRETS is empty, picks a random value in [7..12].

BOLD="\033[1m"; RESET="\033[0m"; YEL="\033[33m"; GRN="\033[32m"; RED="\033[31m"

ENV_FILE="${1:-./env-vars.sh}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

require_cmd(){ command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}Missing dependency:${RESET} $1"; exit 1; }; }
require_cmd vault
require_cmd jq
require_cmd openssl

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

# Required
prompt_if_unset "VAULT_ADDR"  "Enter VAULT_ADDR (e.g., https://vault.example.com:8200):"
prompt_if_unset "VAULT_TOKEN" "Enter VAULT_TOKEN (admin/root token):"
prompt_if_unset "MOUNT_PATH"  "Enter KV v2 mount path (e.g., my-secrets):"

# Optional TLS for CLI
export VAULT_CACERT="${VAULT_CACERT:-}"
export VAULT_SKIP_VERIFY="${VAULT_SKIP_VERIFY:-}"

# Determine count
NUM_SECRETS="${NUM_SECRETS:-}"
if [[ -z "${NUM_SECRETS}" ]]; then
  # random in [7..12]
  NUM_SECRETS="$(( (RANDOM % 6) + 7 ))"
fi

# Sanity reachability
if ! vault status -address="${VAULT_ADDR}" >/dev/null 2>&1; then
  echo -e "${YEL}Warning:${RESET} 'vault status' failed; verify VAULT_ADDR/VAULT_CACERT/VAULT_SKIP_VERIFY and token."
fi

# Ensure KV v2 at MOUNT_PATH (idempotent)
mount_with_slash="${MOUNT_PATH%/}/"
json=$(vault secrets list -address="${VAULT_ADDR}" -format=json || echo "{}")
if echo "$json" | jq -e --arg p "$mount_with_slash" 'has($p)' >/dev/null; then
  type=$(echo "$json" | jq -r --arg p "$mount_with_slash" '.[$p].type')
  if [[ "$type" != "kv" ]]; then
    echo -e "${RED}Mount '${MOUNT_PATH}' exists but is type '${type}'. Aborting.${RESET}"; exit 1
  fi
  ver=$(echo "$json" | jq -r --arg p "$mount_with_slash" '.[$p].options.version // "1"')
  if [[ "$ver" != "2" ]]; then
    echo "Mount '${MOUNT_PATH}' is kv v1; enabling versioning to v2…"
    vault kv enable-versioning -address="${VAULT_ADDR}" "${MOUNT_PATH}" || true
  fi
else
  echo "Enabling kv v2 at path '${MOUNT_PATH}'…"
  vault secrets enable -address="${VAULT_ADDR}" -path="${MOUNT_PATH}" -version=2 kv
fi

# Write secrets

SECRET_PATH="${SECRET_PATH:-}"
if [[ -z "${SECRET_PATH}" ]]; then
  SECRET_PATH="secret-app"
fi

echo -e "Seeding ${BOLD}${NUM_SECRETS}${RESET} secrets into '${MOUNT_PATH}/${SECRET_PATH}'..."
for i in $(seq 1 "${NUM_SECRETS}"); do
  k=$(openssl rand -hex 8)
  v=$(openssl rand -hex 16)
  vault kv put -address="${VAULT_ADDR}" "${MOUNT_PATH}/${SECRET_PATH}/${i}" "key=${k}" "value=${v}" >/dev/null || true
done

echo -e "✅ ${GRN}Sample secrets created.${RESET}"
