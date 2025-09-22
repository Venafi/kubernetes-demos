# Vault on EC2 with TLS configured using Cyberark Certificate Manager — Demo

Create a single-node HashiCorp Vault on Ubuntu 24.04 in EC2. TLS cert for the instance is issued at build time using **CyberArk Certificate Manager (SaaS)** via the `vcert` CLI.  
Ingress to **8200** (API/UI) and **443** (UI) is locked to up to three CIDRs you provide. Currently they are three different CIDRS. Feel free to improve it a comma separated list. 

> ⚠️ **Demo-only.** This is a single node instance, init/unseal done during bootstrap, and the root token is written to disk. Do **not** use for production.

---

## What this template does

- Creates a Security Group allowing **TCP/8200** and **TCP/443** only from:
  - `AllowedVaultCIDR1` (required), plus optional `AllowedVaultCIDR2` and `AllowedVaultCIDR3`.
- Provisions an Ubuntu 24.04 EC2 instance with SSM agent.
- Installs Vault `${VaultVersion}`, configures HTTPS listeners on **8200** and **443** using a cert from CyberArk CM (`CMApiKey`, `CMZone`) via `vcert` `${VCertVersion}`.
- Initializes and unseals Vault (demo), persists:
  - `/root/vault-init.json`
  - `/root/vault-root-token.txt`
  - `/etc/profile.d/vault.sh` (exports `VAULT_ADDR`, `VAULT_CACERT`, `VAULT_TOKEN`)
- Enables KV v2 at your path and seeds **N** random secrets:
  - Mount path: `${SampleSecretsMountPath}`
  - Secrets created under: `${SampleSecretsMountPath}/app1/1..N` and `${SampleSecretsMountPath}/app2/1..N`
  - Count: `${SampleSecretsToCreate}` (defaults to 10)

---

## Prerequisites

- VPC + subnet with egress to the Internet (for package downloads and CyberArk CM API).
- A CyberArk CM SaaS API key and a CM zone that can issue a public cert for your hostname.
- A DNS name you control that you’ll point to the instance’s public IP.
- Your workstation’s public IP (for `AllowedVaultCIDR1`).

---

## Parameters (high-value)

| Parameter | Purpose |
|---|---|
| `VpcId`, `SubnetId` | Where to run the instance. |
| `UbuntuAmiId` | Ubuntu 24.04 AMI (default value is for us-east-2. Update if you use a different region). |
| `InstanceType` | Default `t3.small`. |
| `KeyName` |  Rely on SSM Session Manager. TODO: make this optional |
| `VaultVersion` | Vault version to install. Default 1.20.3 |
| `DevMode` | Leave **`false`** for TLS. `true` runs dev server without TLS (demo only). DevMode=true is not well tested|
| `VaultHost` | FQDN you’ll use for Vault. Certificate CN/SAN will match this. |
| `VCertVersion` | `vcert` CLI version. Default is 5.12.0 |
| `CMApiKey`, `CMZone` | CyberArk CM SaaS credentials (apikey) to enroll the cert. |
| `AllowedVaultCIDR1..3` | Ingress allowlist for 8200/443/22. |
| `SampleSecretsMountPath` | KV v2 mount path to create (e.g., `my-secrets`). |
| `SampleSecretsToCreate` | Number of random secrets to seed (1-15). |

---

## Launch

**Console**  
Create a stack with `vault_ec2.yaml`, fill the parameters as above.

**CLI (example)**

```bash
aws cloudformation deploy \
  --stack-name demo-vault-ec2 \
  --template-file vault_ec2.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
      VpcId=vpc-xxxxxxxx \
      SubnetId=subnet-xxxxxxxx \
      UbuntuAmiId=ami-04f167a56786e4b09 \
      InstanceType=t3.small \
      DevMode=false \
      VaultHost=vault.example.com \
      VCertVersion=5.12.0 \
      CMApiKey=YOUR_CM_API_KEY \
      CMZone='CloudApps\\public-ca' \
      AllowedVaultCIDR1=$(curl -s ifconfig.me)/32 \
      SampleSecretsMountPath=my-secrets \
      SampleSecretsToCreate=5
```

---

## After the stack completes

### 1) Create DNS (Route 53)
Create an **A record** in Route 53 to map your `VaultHost` to the instance’s **public IP** (available in stack outputs). HTTPS handshakes use the FQDN in the issued cert, so DNS must match.

**CLI helper (optional):**
```bash
HOSTED_ZONE_ID=ZXXXXXXXXXXXXX
RECORD=vault.example.com
IP=$(aws cloudformation describe-stacks --stack-name demo-vault-ec2 \
     --query "Stacks[0].Outputs[?OutputKey=='VaultInstancePublicIp'].OutputValue" --output text)

cat > /tmp/rr.json <<EOF
{ "Comment": "Upsert Vault A record",
  "Changes": [{ "Action": "UPSERT",
    "ResourceRecordSet": { "Name": "$RECORD", "Type": "A", "TTL": 60,
      "ResourceRecords": [{ "Value": "$IP" }] } }]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch file:///tmp/rr.json
```

### 2) Grab credentials (via SSM Session Manager)
- Unseal info + root token: `/root/vault-init.json`, `/root/vault-root-token.txt`
- Helpful env: `/etc/profile.d/vault.sh`
  - `VAULT_ADDR=https://${VaultHost}`
  - `VAULT_CACERT=/etc/vault.d/tls/vault.chain.crt`
  - `VAULT_TOKEN=<root token>`

---

## Verify

From your workstation (CIDR allow-listed and DNS set):

```bash
# Health
curl -sSIk https://vault.example.com:8200/v1/sys/health

# UI
open https://vault.example.com/ui/      # or :8200/ui

# vault CLI (recommended)
export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="<root token>"
# If using a private CA chain, also set:
# export VAULT_CACERT=/path/to/chain.pem

vault status
vault secrets list -detailed | grep my-secrets
vault kv list my-secrets/app1
vault kv get  my-secrets/app1/1
```

---

## Outputs

Typical stack outputs include:

- **InstanceId** – EC2 instance id  
- **VaultInstancePublicIp** / **VaultInstancePublicDns** – public addressing for DNS mapping  
- **VaultURL** – `https://${VaultHost}:8200`  
- **VaultURL443** – `https://${VaultHost}/ui/`  
- **SecretsPath** – where sample secrets were created  
- **SampleSecretsMountPath** – the KV mount you can use for policies  
- **AccessNote** – quick access tips

---

## Notes, limits, and cleanup

- Certificate issuance requires the instance to reach CyberArk CM SaaS endpoints.
- The bootstrap seeds random secrets at `${SampleSecretsMountPath}/app1/*` and `/app2/*`.
- To destroy: delete the stack; the EBS volume with the Vault data (file storage) is removed.
