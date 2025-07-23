#!/bin/bash

# Vault and plugin config
export VAULT_VERSION="1.20.0"
export VAULT_PLUGIN_NAME="venafi-pki-backend"
export VAULT_PLUGIN_VERSION="v0.14.0"  # adjust as needed
export VAULT_PLUGIN_SHA_FILE=".plugin-sha"

# Directories
export VAULT_DIR="./vault_data"
export PLUGIN_DIR="./vault_plugins"
export VAULT_CONFIG="./vault.hcl"
export VAULT_BIN="./vault"
export KEYS_FILE="./keys.json"

# Vault env
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_PID_FILE=".vault.pid"
export VAULT_LOG="vault.log"

# Cyberark Certificate Manager Config
export CLOUD_URL=https://REPLACE_WITH_CLOUD_URL
export CYBR_CM_API_KEY="REPLACE_WITH_API_KEY"
export CYBR_ZONE_PRIVATE_CA=REPLACE_WITH_APPLICATION\\REPLACE_WITH_ISSUING_TEMPLATE
export DOMAIN="example.com"
CERT_SUFFIX="$(date +%S%H%M%d%m)"
export CN="cert-${CERT_SUFFIX}.${DOMAIN}"