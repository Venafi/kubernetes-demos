# Harbor on AWS EC2

This directory contains everything to provision and bootstrap a Harbor registry on AWS EC2 with TLS certificates issued by CyberArk Certificate Manager.
Copy `env-vars-template.sh` as `env-vars.sh` and set the values.

## Contents

- `harbor_ec2.yaml` – AWS CloudFormation template that:
  - launches Ubuntu EC2
  - installs Docker + Harbor
  - requests a TLS cert using `vcert`
  - configures Harbor with systemd to survive reboots
- `harbor-bootstrap.sh` – post-provision helper to:
  - log into Harbor
  - create project
  - configure metadata (auto-scan, visibility)
  - create a robot account
  - generate:
    - a Kubernetes pull secret (`harbor-creds.yaml`)
    - local login/logout scripts (`harbor-login.sh`, `harbor-logout.sh`)
- `env-vars.sh` – environment config:
  - `HARBOR_HOST`
  - project/robot names
  - CyberArk Certificate Manager API key + zone for cert issuance

## Workflow

### 1. Provision Harbor on EC2

Deploy the CloudFormation stack:

```bash
aws cloudformation create-stack   --stack-name harbor   --template-body file://harbor_ec2.yaml   --parameters     ParameterKey=KeyName,ParameterValue=<your-key>     ParameterKey=InstanceType,ParameterValue=t3.large
```

This creates an EC2 with Harbor listening at `https://${HARBOR_HOST}` and TLS served from Certificate Manager.

### 2. Bootstrap Harbor

```bash
source env-vars.sh
./harbor-bootstrap.sh
```

Outputs:

- `harbor-creds.yaml` – Kubernetes secret with robot creds
- `harbor-login.sh` / `harbor-logout.sh` – local Docker/Helm login helpers

### 3. Verify

- Visit `https://${HARBOR_HOST}` in a browser (should be trusted cert).  
- Log in with the robot creds from bootstrap.  
- Push/pull a test image:

```bash
docker login ${HARBOR_HOST} -u robot$<project>-ci -p <token>
docker pull alpine:3.20
docker tag alpine:3.20 ${HARBOR_HOST}/<project>/alpine:3.20
docker push ${HARBOR_HOST}/<project>/alpine:3.20
```
