#!/bin/bash

provider="$1"

if [[ -z "$provider" ]]; then
  echo "❌ No identity provider specified to validate_env.sh"
  exit 1
fi

case "$provider" in
  okta)
    required_vars=(OKTA_CLIENT_ID OKTA_CLIENT_SECRET OKTA_AUTH_URL OKTA_SCOPE)
    ;;
  azure)
    required_vars=(AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_AUTH_URL AZURE_SCOPE)
    ;;
  auth0)
    required_vars=(AUTH0_CLIENT_ID AUTH0_CLIENT_SECRET AUTH0_AUTH_URL AUTH0_SCOPE AUTH0_AUDIENCE)
    ;;
  *)
    echo "❌ Unknown provider: $provider"
    exit 1
    ;;
esac

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "❌ Environment variable $var is not set"
    exit 1
  fi
done
