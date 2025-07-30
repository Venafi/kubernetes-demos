#!/bin/bash
set -euo pipefail

source ./env-vars.sh

get_token_okta() {
  local cred
  cred=$(echo -n "${OKTA_CLIENT_ID}:${OKTA_CLIENT_SECRET}" | base64)

  local token
  token=$(curl -s --request POST \
    --url "${OKTA_AUTH_URL}/v1/token" \
    --header "Authorization: Basic ${cred}" \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data "grant_type=client_credentials&scope=${OKTA_SCOPE}")

  echo "$token" | jq -r .access_token
}

get_token_azure() {
  local cred
  cred=$(echo -n "${AZURE_CLIENT_ID}:${AZURE_CLIENT_SECRET}" | base64)

  local token
  token=$(curl -s --request POST \
    --url "${AZURE_AUTH_URL}/oauth2/v2.0/token" \
    --header "Authorization: Basic ${cred}" \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data "grant_type=client_credentials&scope=${AZURE_SCOPE}")

  echo "$token" | jq -r .access_token
}

get_token_auth0() {
  local cred
  cred=$(echo -n "${AUTH0_CLIENT_ID}:${AUTH0_CLIENT_SECRET}" | base64)

  local token
  token=$(curl -s --request POST \
    --url "${AUTH0_AUTH_URL}oauth/token" \
    --header "Authorization: Basic ${cred}" \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data "grant_type=client_credentials&scope=${AUTH0_SCOPE}&audience=${AUTH0_AUDIENCE}")

  echo "$token" | jq -r .access_token
}

issue_cert() {
  local jwt="$1"
  local provider="$2"

  local cn="$provider-$CERT_NAME"
  local tmp_dir="/tmp/$cn"
  mkdir -p "$tmp_dir"

  echo "🔐 Requesting certificate for CN: $cn"

  local vcp_token
  vcp_token=$(vcert getcred -p vcp \
    --token-url "$VCP_TOKEN_URL" \
    --external-jwt "$jwt" \
    --format json | jq -r .access_token)

  if [[ -z "$vcp_token" || "$vcp_token" == "null" ]]; then
    echo "❌ Failed to obtain VCP access token"
    exit 1
  fi

  local response_json
  response_json=$(vcert enroll --platform "$PLATFORM" \
    -t "$vcp_token" \
    --cn "$cn" \
    -z "$VCP_ZONE" \
    --csr service \
    --chain root-first \
    --format json \
    --no-prompt)

  echo "$response_json" > "$tmp_dir/response.json"
  jq -r '.Certificate' <<< "$response_json" > "$tmp_dir/${cn}.pem"
  jq -r '.Chain[]' <<< "$response_json" > "$tmp_dir/${cn}-chain.pem"
  jq -r '.PrivateKey' <<< "$response_json" > "$tmp_dir/${cn}-key.pem"

  echo "\n📜 Certificate Preview:"
  openssl x509 -in "$tmp_dir/${cn}.pem" -text -noout | head -n 10

  echo "\n✅ Cert saved in: $tmp_dir"
  ls -lh "$tmp_dir"
}

main() {
  if [[ $# -ne 1 ]]; then
    echo "Usage: $0 [okta|azure|auth0]"
    exit 1
  fi

  local provider="$1"
  ./validate_env.sh "$provider"

  local jwt=""
  case "$provider" in
    okta)
      jwt=$(get_token_okta)
      ;;
    azure)
      jwt=$(get_token_azure)
      ;;
    auth0)
      jwt=$(get_token_auth0)
      ;;
    *)
      echo "❌ Unknown provider: $provider"
      exit 1
      ;;
  esac

  if [[ -z "$jwt" || "$jwt" == "null" ]]; then
    echo "❌ Failed to retrieve JWT"
    exit 1
  fi

  issue_cert "$jwt" "$provider"
}

main "$@"