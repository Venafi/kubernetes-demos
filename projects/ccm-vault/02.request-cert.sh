#!/bin/bash
set -e
source ./env-vars.sh

export VAULT_ADDR
export VAULT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE")

PLUGIN_SHA=$(cat $VAULT_PLUGIN_SHA_FILE)

echo "📌 Registering CyberArk Certificate Manager OSS plugin ($VAULT_PLUGIN_NAME)..."
$VAULT_BIN plugin register \
   -sha256="$PLUGIN_SHA" \
   secret "$VAULT_PLUGIN_NAME" || true

#$VAULT_BIN write sys/plugins/catalog/secret/$VAULT_PLUGIN_NAME \
#    sha_256="$PLUGIN_SHA" command="$VAULT_PLUGIN_NAME"

echo "📦 Checking if secrets engine is already enabled at: cyberark-cm/"
if $VAULT_BIN secrets list -format=json | jq -e '."cyberark-cm/"' >/dev/null; then
  echo "🔁 Secrets engine already enabled at cyberark-cm/. Skipping enable step."
else
  echo "📦 Enabling plugin at mount path: cyberark-cm/"
  $VAULT_BIN secrets enable -path=cyberark-cm \
    -plugin-name="$VAULT_PLUGIN_NAME" \
    plugin
fi

echo "⚙️ Configuring issuer with Cyberark Certificate Manager..."
$VAULT_BIN write cyberark-cm/venafi/vaas \
  apikey="$CYBR_CM_API_KEY" \
  url="$CLOUD_URL" \
  zone="$CYBR_ZONE_PRIVATE_CA"

echo "📘 Defining role.."
$VAULT_BIN write cyberark-cm/roles/vaas \
    venafi_secret=vaas \
    ttl=86400 \
    service_generated_cert=true \
    generate_lease=true store_by=serial store_pkey=true

echo "📄 Requesting certificate for $CN..."

CERT_OUTPUT=$($VAULT_BIN write -format=json cyberark-cm/issue/vaas common_name="$CN")

#echo $CERT_OUTPUT
echo "$CERT_OUTPUT" | jq -r '.data.certificate' > cert.pem
echo "$CERT_OUTPUT" | jq -r '.data.private_key' > key.pem
echo "$CERT_OUTPUT" | jq -r '.data.ca_chain' > ca.pem

echo "📜 Certificate Preview:"
openssl x509 -in cert.pem -text -noout | head -n 10

echo ""
echo "✅ Certificate issued and saved:"
ls -lh cert.pem key.pem ca.pem
