# CyberArk Secrets Hub — Vault Policy/Role Setup

> **Need a Vault instance first?**  
> If you don’t already have a Vault, use the CloudFormation [guide](../../scripts/vault/README.md) to create one, then come back here.

This module prepares an **existing HashiCorp Vault** for CyberArk Secrets Hub:

- Creates/updates a **policy** and **JWT role** for a KV v2 mount you choose
- Enables and configures the **`auth/jwt`** method against your **CyberArk SecretsHub OIDC** discovery URL
- Optionally, **seeds sample secrets** into your chosen mount (random **7–12** by default)

Scripts:

- `create-roles-and-policy-for-secrets-hub.sh` — configures policy, JWT auth, and role; calls the seeding script
- `create-sample-secrets.sh` — ensures KV v2 at `MOUNT_PATH`, then seeds sample secrets
- `env-vars.sh` — your environment values (created from the provided template `env-vars.template.sh`)

---

## Prerequisites

- HashiCorp **Vault CLI** (`vault`)
- **jq**, **curl**, **openssl**
- Network access from your machine (or CI) to the Vault address
- Your **CyberArk Identity / OIDC** discovery base URL

> If Vault or IdP uses a private CA, have the CA chain PEM for `VAULT_CACERT` (Vault) and/or `OIDC_DISCOVERY_CA_PEM` (IdP).

---

## Quick start

1) **Create your env file from the template**

```bash
cp env-vars-template.sh env-vars.sh
$EDITOR env-vars.sh
```

> You can leave any variable blank; the script will prompt interactively when a TTY is present.

### Environment variables (to be defined in `env-vars.sh`)

| Name | Description | Default | Required/Optional |
|---|---|---|---|
| `VAULT_ADDR` | Vault base URL (include scheme, and port if not 443) | `https://<vault-host>:8200` | **Required** |
| `VAULT_TOKEN` | Admin/root token used to configure policy/auth/role | *(none)* | **Required** |
| `VAULT_CACERT` | Path to CA chain that validates Vault TLS cert | *(empty)* | Optional |
| `VAULT_SKIP_VERIFY` | If `true`, skip TLS verification for the Vault CLI (testing only) | *(empty/false)* | Optional |
| `MOUNT_PATH` | KV v2 mount path for Secrets Hub | `secret-sample` | **Required** |
| `ROLE_NAME` | JWT role name used by Secrets Hub | `SecretsHub-${MOUNT_PATH}-Role` | **Required** |
| `POLICY_NAME` | Vault policy attached to the JWT role | `${ROLE_NAME}-Policy` | **Required** |
| `JWT_PATH` | Path where JWT auth method is mounted | `jwt` | **Required** |
| `OIDC_DISCOVERY_URL` | **Base** discovery URL of your CyberArk OIDC app (no `/.well-known` suffix; trailing `/` OK). Script fetches the exact issuer. | *(none)* | **Required** |
| `OIDC_DISCOVERY_CA_PEM` | CA chain PEM so Vault can validate IdP discovery | *(empty)* | Optional |
| `OIDC_AUDIENCE` | Allowed audience (`aud`) for the role | `SecretsHub` | Optional |
| `SUBJECT` | Allowed subject(s) for the role (`sub` claim) | `SECRETS_HUB_HASHI_IDENTITY_APPLICATION_USER` | Optional |
| `TOKEN_TTL` | Role-issued token TTL (seconds) | `3600` | Optional |
| `NUM_SECRETS` | How many sample secrets to seed (random if empty) | *(empty → random 7–12)* | Optional |

> The policy grants read/list on `${MOUNT_PATH}/data/*`, metadata ops on `${MOUNT_PATH}/metadata/*`, and read on `sys/mounts/${MOUNT_PATH}/*`.

2) **Run the setup**

```bash
chmod +x create-roles-and-policy-for-secrets-hub.sh create-sample-secrets.sh
./create-roles-and-policy-for-secrets-hub.sh                  # auto-loads ./env-vars.sh
# or specify a different env file
./create-roles-and-policy-for-secrets-hub.sh ./path/to/env-vars.sh
```

What it does:
- Writes/overwrites the **policy** and **JWT role**
- Enables/configures **`auth/jwt`** (if missing)
- Calls `create-sample-secrets.sh` to **seed random 7–12 secrets** (unless `NUM_SECRETS` set)


3) **Use the values in Secrets Hub**

When adding the HashiCorp secret store in Secrets Hub, supply:
- **Vault address** = `VAULT_ADDR`
- **Authentication path** = `JWT_PATH` (default `jwt`)
- **Role name** = `ROLE_NAME`
- **Mount path** = `MOUNT_PATH`

---

4) **Seed additional secrets by simply running**
```bash
 SECRET_PATH=new-app1 ./create-sample-secrets.sh
```

This will create addtional secrets under MOUNT_PATH/SECRET_PATH. Rerun discovery in Secrets Hub to discover new secrets. 

---

## Troubleshooting

- **`error checking oidc discovery URL`**  
  Use the **base** discovery URL (no `/.well-known`), and ensure Vault can resolve/verify the IdP. Set `OIDC_DISCOVERY_CA_PEM` if your IdP chain isn’t public.
- **TLS errors (Vault or IdP)**  
  Provide `VAULT_CACERT` (Vault) and/or `OIDC_DISCOVERY_CA_PEM` (IdP discovery). Avoid `VAULT_SKIP_VERIFY=true` except for quick tests.
- **Mount isn’t KV v2**  
  Re-run; the seeding script upgrades v1 → v2 or enables v2 if missing.

---

## Clean-up (optional)

```bash
vault delete  auth/${JWT_PATH}/role/${ROLE_NAME}  -address="${VAULT_ADDR}"
vault policy delete ${POLICY_NAME}                -address="${VAULT_ADDR}"
# (Optional) remove sample secrets or disable the mount entirely:
# vault kv metadata delete ${MOUNT_PATH}/*        -address="${VAULT_ADDR}"
# vault secrets disable ${MOUNT_PATH}             -address="${VAULT_ADDR}"
```

---

## Security

- Treat `env-vars.sh` as **sensitive** (contains admin token). Add to `.gitignore`:
  ```gitignore
  env-vars.sh
  ```
- These scripts are **for demos/labs**. Tighten policies, claims, TTLs, and network ACLs before production.
