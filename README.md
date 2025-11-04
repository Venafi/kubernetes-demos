# Kubernetes Demos

This repository contains demos that show how to secure Kubernetes workloads with **CyberArk Certificate Manager**

> ⚠️ These are demos for learning. They are simplified and not production-ready.

---

## Assumptions
- You have access to CyberArk Certificate Manager and have the entitlements to use **Workload Identity Manager** and **Kubernetes add-on**
- If you do not, sign up for an account at https://ui.venafi.cloud . 

## Comprehensive Use Cases

The [`main/`](main) directory contains **full, end-to-end scenarios**, such as:
- SaaS quick path
- Certificate Discovery
- Istio service mesh with mTLS and cert issuance
- Workload Identity Manager for SPIFFE compliant certs with enterprise PKI for service mesh
- Cyberark CLI based mechanism (`venctl`) to install and manage Kubernetes components 
- Redhat Operator based mechanism (as an alternate path to `venctl`) to manage Kubernetes components in OpenShift 

Refer to the [README](main/README.md) to get started with configurations in the SaaS and runtime instructions provided [here](main/CLOUD-DEMO.md)

If you prefer to use a ready-to-use EC2 machine with a cluster along with all the dependencies, just reach out. 

---

## Projects

The [`projects/`](projects) directory contains smaller, focused demos.  
Each project folder has its own README with setup instructions (or will have one soon).

| Project (folder) | Description | README |
|------------------|-------------|--------|
| `awspca`        | AWS Private CA integration | [README](projects/aws-pca/README.md) |
| `ccm-agent` | Discover and inventory Kubernetes certificates using Federated Identity | [README](projects/ccm-agent/README.md) |
| `ccm-idp` | Issue TLS certs with service accounts using Org Identity Provider without APIKEY | [README](projects/ccm-idp/README.md) |
| `ccm-vault`      | Certificate Manager Integration with HashiCorp Vault | [README](projects/ccm-vault/README.md) |
| `kong-mesh`      | Cyberark Workload Identity Manager + Kong Mesh | [README](projects/kong-mesh/README.md) |
| `nginx-plus`      | Cyberark Certificate Manager with F5 NGINX Plus | [README](projects/nginx-plus/README.md) |
| `secrets-hub`      | Discover Hashicorp Vault secrets from Cyberark Secrets Hub | [README](projects/secrets-hub/README.md) |
| `secrets-manager`   | Issue certs from CyberArk Secrets Manager with Certificate Manager Integration | [README](projects/secrets-manager/README.md) |
| `discovery-and-context`   | Configure Cyberark Discovery and Context service for Kubernetes Secrets | [README](projects/discovery-context/README.md) |

---

## Clusters

The [`scripts/`](scripts) directory contains cloud provider specific scripts to stand up a cluster. 

| Scripts (folder) | Description | README |
|------------------|-------------|--------|
| `EKS (AWS)`        | Full end to end EKS cluster build and destroy | [README](scripts/aws/README.md) |
| `AKS (Azure)` | Full end to end AKS cluster build and destroy | [README](scripts/azure/README.md) |
| `GKE (Google Cloud)` | Full end to end GKE cluster build and destroy | [README](scripts/gcp/README.md) |
| `OpenShift (RedHat)` | Full end to end OpenShift (ROSA) cluster build and destroy | [README](scripts/openshift/README.md) |
| `Kind (for local)` | Kind cluster for quick testing | [README](scripts/kind/README.md) |

## Misc
The [`scripts/`](scripts) directory miscellaeous work for supporting usecases. 

| Scripts (folder) | Description | README |
|------------------|-------------|--------|
| `HashiCorp Vault` | TLS Enabled Hashicorp Vault Instance on EC2 using CloudFormation | [README](scripts/vault/README.md) |
| `registry`        | Full setup and configuration for Harbor Registry | [README](scripts/registry/README.md) |
| `ccm-mirror` | Scripts to mirror charts and images to target regisry | [README](scripts/ccm-mirror/README.md) |


## Contributing

- Keep demos simple and reproducible.  
- Add/update README.md files in each `projects/<name>/` directory.  
- Update this table when new projects are added.  

---

## License

[Apache 2.0](LICENSE)
