# Getting started with Jetstack Secure

## Assumptions
- You are a Venafi Jetstack Secure customer and you have access to credentials to access enterprise builds
- If you do not, sign up for an account at https://platform.jetstack.io and reach out for access to credentials

## Setting up your environment 
- Copy [settings-template.sh] (settings-template.sh) as `settings.sh`. Run `cp settings-template.sh settings.sh`. This is a one time work unless new environment variables are introduced in the template. 
- Set the JS_ENTERPRISE_CREDENTIALS_FILE in `settings.sh` with the file location of JSON credentials that you have been provided to pull enterprise images.  
- Additionally, file `settings.sh` contains environment variables that will be used throughout the setup and configuration. Make sure to set the values as needed. Examples are provided in the comments. 

## Creating your Kubernetes cluster
The scripts are written with the assumption that you will be setting up a GKE cluster and as such have access to Google Cloud Platform. If you plan to operate in a cluster other than GKE, you can ignore the cluster creation and jump right into cluster configuration. 

- To create a cluster including a Google Certficate Authority Service, simply run `make fresh-start`
- This will create a brand new GKE cluster, a new Google Certificate Authority Serivce and installs Jetstack cert-manager along with the policy approver addon. 
- It should take about 10 mins to build and configure a cluster.

## Configuring your Kubernetes cluster

- Skip this step if you are creating a brand new cluster with `fresh-start`
- If you are bringing your own cluster then simply run `make cluster-addons` 
- Jetstack cert-manager along with the policy approver addon will be added to the cluster

## Validating your cluster
- Check if the components of Jetstack Secure are installed and running.
- Run `kubectl get pods -n jetstack-secure`. This should show that pods are up and running. 
```
❯ kubectl get pods -n jetstack-secure
NAME                                            READY   STATUS    RESTARTS   AGE
cert-manager-75b4649b6f-hcwkc                   1/1     Running   0          52s
cert-manager-approver-policy-864d6bc45c-wvmcb   1/1     Running   0          15s
cert-manager-cainjector-5d7485d9d8-h85wn        1/1     Running   0          52s
cert-manager-webhook-fb6b96c7-wx22d             1/1     Running   0          52s
```

# Connecting the cluster to Jetstack Secure Dashboard
- Log back into Jetstack Secure https://platform.jetstack.io and click on Clusters.
- For specific instructions and screenshots click [here](docs/jetstack-secure.md#connecting-a-cluster-to-jetstack-secure)
- Validate that the Jetstack Secure Agent has been installed and running in the cluster.
- Run `kubectl get pods -n jetstack-secure`
```
❯ kubectl get pods -n jetstack-secure
NAME                                            READY   STATUS    RESTARTS   AGE
agent-6bf697664b-ww9xn                          1/1     Running   0          49s
cert-manager-75b4649b6f-hcwkc                   1/1     Running   0          11m
cert-manager-approver-policy-864d6bc45c-wvmcb   1/1     Running   0          11m
cert-manager-cainjector-5d7485d9d8-h85wn        1/1     Running   0          11m
cert-manager-webhook-fb6b96c7-wx22d             1/1     Running   0          11m
```
The `jetstack-secure` namespace how has an addtional pod called `agent-6bf697664b-ww9xn` that is responsible for pushing the certificates to Jetstack Secure dashboard. 

# 01. Request a certificate 

To create and approve a certificate manually follow the instructions [here](docs/01.create-certificate.md#creating-a-certificate)
Login to Jetstack Secure dashboard to view the certificate data

# 02. Creating policies for auto approval

The Venafi Jetstack Enterprise Policy Approver is an enterprise addon to define and manage `CertificateRequestPolicy` resources that provides the ability to
- define policies locally in-cluster that enforces how `CertificateRequests` are processed
- leverage Venafi plugin to locally enforce policies defined in Venafi without replicating them
- leverage `rego` plugin to leverage policies defined using Open Policy Agent 

To automatically approve certificate requests with `CertificateRequestPolicy` follow the instructions [here](docs/02.auto-approve-certs.md#create-policies-for-auto-approval)

Refresh the Jetstack Secure dashboard to look at new data pushed by the agent. Review the data.

# 03. Pushing certificates for visibility to Venafi Trust Protection Platform 

The Venafi Jetstack Enterprise certificate sync module is an enterprise addon to synchronize TLS secrets that are in cluster into a policy folder defined in Venafi for management. This allows Venafi Administrators to understand the various Certificate Authrorities used for the certificates and define appropriate policies to manage compliance. 

To setup the ability to push all TLS secrets to Venafi Trust Protection Platform follow the instructions [here](docs/03.cert-sync-to-venafi.md#push-certificate-data-to-venafi-trust-protection-platform)

Refresh the Jetstack Secure dashboard to look at new data pushed by the agent. Review the data. Additionally, access the Venafi Trust Protection Platform. Certificates pushed by the cert sync module will show up the folder designated for discovery.

# 04. Create identities for pods with Jetstack cert-manager CSI driver

Jetstack cert-manager CSI driver is an addon to cert-manager to provide TLS indentities to pods running in-cluster. The identities are directly injected into the pod's tmp filesystem thereby avoiding the need to create and manage TLS secrets in Kubernetes.  

Follow the instructions [here](docs/04.pod-identities-csi-driver.md#securing-pods-with-identities-using-the-venafi-jetstack-cert-manager-csi-driver) to setup Jetstack cert-manager CSI driver and validate that certs are injected into the pods.

# 05. Create identities for pods with Jetstack cert-manager SPIFFE driver

Jetstack cert-manager CSI SPIFFE driver is an addon to cert-manager to provide TLS indentities to pods running in-cluster using SPIFFE. The identities are directly injected into the pod's tmp filesystem thereby avoiding the need to create and manage TLS secrets in Kubernetes.  

Follow the instructions [here](docs/05.pod-identities-csi-driver-spiffe.md#securing-pods-with-identities-using-the-venafi-jetstack-cert-manager-csi-driver-spiffe) to setup Jetstack cert-manager CSI SPIFFE driver and validate that SPIFFE SVIDS are injected into the pods

# 06. Issue certificates with an issuer running outside the cluster

The Venafi Jetstack Enterprise issuer for cert-manager provides a mechanism for organizations to run an issuer either in-cluster or isolated from the cluster. The isolated issuer bootstraps itself with an intermediate CA issued by Venafi and keeps it in memory. This is critical for organizaitons that are looking for ways to avoid having to store certificate information including the privateKey as TLS secrets. 

Follow the instructions [here](docs/06.isolated-issuer.md#configuring-and-running-venafi-jetstack-secure-isolated-issuer)

# Use Jetstack cert-mananager and istio-CSR projects to sign mesh workloads

Jetstack cert-manager istio-csr is a cert-manager addon that provides that ability to sign mesh workloads with a cert-manager issuer.

## Signing mesh workloads with Venafi Trust Protection Platform 
Sign mesh workloads with Venafi Trust Protection Platform

## Signing mesh workloads with Venafi TLS Protect Cloud
Sign mesh workloads with Venafi TLS Protect Cloud

## Signing mesh workloads with Hashicorp Vault
Sign mesh workloads with Hashicorp Vault

## Signing mesh workloads with Google Certificate Authority Service
Sign mesh workloads with Google Certificate Authority Service
## Signing mesh workloads with AWS ACM Private Certificate Authority 
Sign mesh workloads with AWS ACM Private Certificate Authority

