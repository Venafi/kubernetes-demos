#!/bin/bash
set -e
source ./env-vars.sh

export VAULT_ADDR

if $VAULT_BIN status -format=json | jq -e '.initialized' | grep false >/dev/null; then
  echo "🔑 Initializing Vault..."
  $VAULT_BIN operator init -format=json -key-shares=1 -key-threshold=1 > "$KEYS_FILE"
else
  echo "✅ Vault already initialized."
fi

if $VAULT_BIN status -format=json | jq -e '.sealed' | grep true >/dev/null; then
  echo "🔓 Unsealing Vault..."
  UNSEAL_KEY=$(jq -r '.unseal_keys_b64[0]' "$KEYS_FILE")
  $VAULT_BIN operator unseal "$UNSEAL_KEY"
fi

ROOT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE")
$VAULT_BIN login "$ROOT_TOKEN" >/dev/null
echo "🔐 Logged in with root token."
