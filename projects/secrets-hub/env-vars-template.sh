# env-vars-template.sh — copy to env-vars.sh and edit

# --- Vault ---
export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN=""                    # admin/root for setup
# export VAULT_CACERT="/path/to/vault-ca-chain.pem"
# export VAULT_SKIP_VERIFY="false"       # true only for testing

# --- KV v2 mount & auth paths ---
export MOUNT_PATH="sample-secrets"
export ROLE_NAME="SecretsHub-${MOUNT_PATH}-Role"
export POLICY_NAME="${ROLE_NAME}-Policy"
export JWT_PATH="jwt"

# --- OIDC (CyberArk Identity / Secrets Hub app) ---
# Use the BASE discovery URL; do NOT append '/.well-known'
export OIDC_DISCOVERY_URL="https://<tenant>.id.cyberark.cloud/<oauth2-app-path>/"
# Optional CA chain to validate discovery if not public
# export OIDC_DISCOVERY_CA_PEM="/path/to/idp-ca-chain.pem"

# --- Claims / token ---
export OIDC_AUDIENCE="SecretsHub"
export SUBJECT="SECRETS_HUB_HASHI_IDENTITY_APPLICATION_USER"
export TOKEN_TTL="3600"

# --- Sample secrets (optional) ---
# Leave empty for a random 7–12 secrets; set an int to override
export NUM_SECRETS=""
