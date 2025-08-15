# CyberArk Kubernetes Demos — Runtime Instructions

> Make sure you have a Cyberark Certificate Manager tenant and you have followed the [documentation][def]

This guide walks you through how to run the CyberArk Certificate Manager for Kubernetes demo using the `cloud-demo.sh` orchestrator. The scripts can be executed on:

- An **EC2 instance** provisioned via the provided CloudFormation template (`ubuntu-kind-ec2.yaml`) with kind-based Kubernetes
- An existing **Kubernetes cluster** (e.g., EKS, GKE, or OpenShift)

---

## 🚀 Option 1: EC2 + Kind (CloudFormation Workflow)

### Step 1: Launch EC2 via CloudFormation

1. Go to the AWS Console and deploy the `ubuntu-kind-ec2.yaml` template.
2. Make sure to:
   - Specify your key pair name for SSH access
   - Provide your **public IP** (e.g., `203.0.113.5/32`) to restrict access
   - Set `APIKey`, `CloudRegion`, `TeamName` parameters as needed
   - Pick your VPC and subnet
   - **NOTE:** The default AMI is for an Ubuntu image in us-east-2. Set the correct AMI for other regions.

### Step 2: SSH into the EC2 Instance

```sh
ssh -i <your-key.pem> ubuntu@<EC2 Public IP>
```

#### Review the instance 
The output of what is provisioned in the machine is logged in `/var/log/cloud-init-output.log` You can review to understand what was done. If the post provision action failed for any reason, you will find the cause in this file. 

You will find a directory called "kubernetes-demos" in the home directory. 
Additionally, review the file `kubernetes-demos/main/env/env-vars.sh` Some of the values you provided when the machine was provisioned is written to this file. 

Your main orchestrator for the demo is `cloud-demo.sh` Just running this file on your terminal will provide you with usage guidelines. 


### Step 3: Start the Demo

```sh
cd ~/kubernetes-demos/main
./cloud-demo.sh
```

> The EC2 instance has kind, kubectl, docker, venctl, istioctl preinstalled.

---

## 🔁 Option 2: Existing Kubernetes Cluster

You can run the same demo from your laptop or jump host if you have access to an existing cluster (EKS, GKE, etc.) and proper `kubectl` context:
**NOTE** You need to create `/env/env-vars.sh` from `/env/env-vars-template.sh` and set the values yourself before you start. You will also need to make sure your local machine has all the pre-requisites installed. The pre-requisites are docker, venctl, istioctl 


```sh
cd kubernetes-demos/main
./cloud-demo.sh
```

---

## 📜 Script Flow and Outcomes

The scripts under `scripts/` are executed by `cloud-demo.sh` and orchestrate the demo lifecycle.

### Available Commands

| Command                       | Description |
|------------------------------|-------------|
| `01.prep-env`                | Prepare environment. Create temporary directories |
| `02.create-service-accounts` | Create CyberArk Certificate Manager Service Accounts |
| `03.prep-kubernetes`         | Create namespaces, secrets required for demos |
| `04.install [mode]`          | Install CyberArk Certificate Manager in the cluster <br> Supported modes:<br>• `venctl` (default) - Uses Helm and `venctl`<br>• `operator` - Uses OLM + VenafiInstall CR |
| `05.configure-demo`          | Create Certificate policies and issuers |
| `06.create-sample-data`      | Seed demo environment with sample workloads and certs |
| `07.install-istio-csr [mode]`| Prepare and install Istio SPIFFE integration <br> Supported modes:<br>• `venctl` (default)<br>• `operator` |
| `08.install-istio`           | Install and configure Istio Service Mesh |
| `09.deploy-public-gateway`   | OPTIONAL - Deploy Gateway with TLS cert and DNS mapping |
| `show`                       | Demonstrate CyberArk Certificate Manager capabilities <br> Subcommands: `issuers`, `policies`, `secrets`, `svid <app>`, `app-url`, `kiali-url` <br> Advanced: `port_forward_service <name> <namespace> <service> <target_port> <local_port>` |
| `stop-port-forwards`         | Stop all background port forwards |
| `clean`                      | OPTIONAL - Remove everything <br> Subcommands: `intermediates`, `configuration`, `configuration <config_name>` |

---

### Examples

```bash
./cloud-demo.sh 01.prep-env
./cloud-demo.sh 04.install
./cloud-demo.sh 04.install operator
./cloud-demo.sh show issuers
./cloud-demo.sh show svid frontend
./cloud-demo.sh show app-url

---

## 🧭 Common Commands

- Show all supported commands:
  ```sh
  ./cloud-demo.sh
  ```

- Show SVID for an app:
  ```sh
  ./cloud-demo.sh show svid frontend
  ```

- Access the demo app (swag shop):
  ```sh
  ./cloud-demo.sh show app-url
  ```

- Stop port forwards:
  ```sh
  ./cloud-demo.sh stop-port-forwards
  ```

- Clean up the environment:
  ```sh
  ./cloud-demo.sh clean
  ```

---

## 🌐 Access CyberArk Certificate Manager UI

After running `04.install`, `06.create-sample-data`, and `08.install-istio`, login to the UI:

```
https://<your-tenant>.venafi.cloud
```

Navigate to:

- **Installations → Kubernetes Clusters** (for agent-based telemetry)
- **Inventory → Firefly Issuer Certificates** (to see SVID certs)

---

## ✅ Success Criteria

- Sample workloads (frontend/backend) are running
- TLS cert issued by CyberArk is visible in Istio Gateway secret
- Swag shop is reachable on DNS with valid HTTPS
- SVIDs can be inspected via `istioctl proxy-config secret` or `show svid`
- CyberArk UI reflects clusters, issuers, certs in the expected views

---

## 🧹 Cleanup

Use the built-in cleaner:

```sh
./cloud-demo.sh clean
```

To clean intermediate certs:

```sh
./cloud-demo.sh clean intermediates
```

[def]: README.md