#!/bin/bash
set -e
source ./env-vars.sh

mkdir -p $VAULT_DIR $PLUGIN_DIR

echo "📥 Downloading Vault for macOS ARM..."
curl -sLo vault.zip "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_darwin_arm64.zip"
unzip -o vault.zip > /dev/null
chmod +x vault
rm vault.zip

echo "📥 Downloading Cyberark Certificate Manager Vault plugin ZIP..."
PLUGIN_ZIP="${VAULT_PLUGIN_NAME}_${VAULT_PLUGIN_VERSION}_darwin_arm.zip"
PLUGIN_URL="https://github.com/Venafi/vault-pki-backend-venafi/releases/download/${VAULT_PLUGIN_VERSION}/${PLUGIN_ZIP}"

curl -sLo "$PLUGIN_ZIP" "$PLUGIN_URL"
unzip -o "$PLUGIN_ZIP" -d temp_plugin > /dev/null
rm "$PLUGIN_ZIP"

PLUGIN_PATH=$(find temp_plugin -type f -name "$VAULT_PLUGIN_NAME")
if [[ -z "$PLUGIN_PATH" ]]; then
  echo "❌ Failed to find plugin binary in ZIP"
  exit 1
fi

mv "$PLUGIN_PATH" "${PLUGIN_DIR}/${VAULT_PLUGIN_NAME}"
chmod +x "${PLUGIN_DIR}/${VAULT_PLUGIN_NAME}"
rm -rf temp_plugin

echo "🔐 Calculating SHA256 of plugin..."
shasum -a 256 "${PLUGIN_DIR}/${VAULT_PLUGIN_NAME}" | awk '{print $1}' > "$VAULT_PLUGIN_SHA_FILE"

echo "🚀 Starting Vault server..."
$VAULT_BIN server -config=$VAULT_CONFIG > $VAULT_LOG 2>&1 &
VAULT_PID=$!
echo $VAULT_PID > $VAULT_PID_FILE

sleep 5

./vault-init-unseal.sh
