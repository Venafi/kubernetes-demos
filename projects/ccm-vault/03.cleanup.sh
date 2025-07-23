#!/bin/bash
set +e
source ./env-vars.sh

if [[ -f "$VAULT_PID_FILE" ]]; then
  kill "$(cat $VAULT_PID_FILE)"
  wait "$(cat $VAULT_PID_FILE)" 2>/dev/null
  rm -f $VAULT_PID_FILE
fi

echo "🧽 Cleaning up..."
rm -rf $VAULT_DIR $PLUGIN_DIR vault vault.zip vault.log \
       $VAULT_PLUGIN_SHA_FILE $KEYS_FILE \
       cert.pem key.pem ca.pem LICENSE.txt

echo "✅ Clean up complete."
