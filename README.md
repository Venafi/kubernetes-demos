# Getting started with Venafi TLS Protect For Kubernetes

## Assumptions
- You are a Venafi TLS Protect for Kubernetes (TLSPK) customer and you have access to credentials to access enterprise builds
- If you do not, sign up for an account at https://platform.jetstack.io and reach out for access to credentials. Getting access to enterprise images is controlled by a feature flag that needs to be enabled. 

## Setting up your environment 
- Copy [settings-template.sh] (settings-template.sh) as `settings.sh`. Run `cp settings-template.sh settings.sh`. This is a one time work unless new environment variables are introduced in the template. We update the version numbers of Helm charts and images regularly so keep your `settings.sh` up-to-date with the template. 
- Set the JS_ENTERPRISE_CREDENTIALS_FILE in `settings.sh` with the file location of JSON credentials that you have been provided to pull enterprise images.  
- Additionally, file `settings.sh` contains environment variables that will be used throughout the setup and configuration. Make sure to set the values as needed. Examples are provided in the template.

## Creating your Kubernetes cluster
The scripts are written with the assumption that you will be setting up a GKE cluster and as such have access to Google Cloud Platform. If you plan to operate in a cluster other than GKE, you can ignore the cluster creation and jump right into cluster configuration. 

- To create a cluster including a Google Certficate Authority Service, simply run `make fresh-start`
- This will create a brand new GKE cluster, a new Google Certificate Authority Service and installs a few required components. The target used for the required components is `cluster-addons` 
- It should take about 10 mins to build and configure a cluster.

## Configuring your Kubernetes cluster

- Skip this step if you are creating a brand new cluster with `fresh-start`
- If you are on an openshift environemnt run `make update-openshift-venafi-scc`
- If you are bringing your own cluster then simply run `make cluster-addons` 
- Enterprise cert-manager along with the policy-approver, trust-manager and the Venafi Enhanced Issuer will be installed in the cluster when you run the `cluster-addons` target

## Validating your cluster
- Check if the components of TLSPK are installed and running.
- Run `kubectl get pods -n jetstack-secure`. This should show that pods are up and running. 
```
❯ kubectl get pods -n jetstack-secure

NAME                                            READY   STATUS    RESTARTS   AGE
cert-manager-68d4cb5b69-qz22k                   1/1     Running   0          2m9s
cert-manager-approver-policy-7554446954-xk7mg   1/1     Running   0          90s
cert-manager-cainjector-6f4d8bc89-vkggv         1/1     Running   0          2m9s
cert-manager-webhook-5cbf55594c-tzvj6           1/1     Running   0          2m9s
trust-manager-5778457f48-mzkj6                  1/1     Running   0          67s
venafi-enhanced-issuer-7c9b979cbf-mbwfp         1/1     Running   0          35s
```

# Connecting the cluster to TLS Protect for Kubernetes Dashboard
- Log back into TLS Protect for Kubernetes https://platform.jetstack.io and click on Clusters.
- For specific instructions and screenshots click [here](docs/jetstack-secure.md#connecting-a-cluster-to-jetstack-secure)
- Validate that the TLSPK Agent has been installed and running in the cluster.
- Run `kubectl get pods -n jetstack-secure`
```
❯ kubectl get pods -n jetstack-secure
NAME                                            READY   STATUS    RESTARTS   AGE
agent-656b6b97c-24zfj                           1/1     Running   0          21s
cert-manager-68d4cb5b69-qz22k                   1/1     Running   0          4m40s
cert-manager-approver-policy-7554446954-xk7mg   1/1     Running   0          4m1s
cert-manager-cainjector-6f4d8bc89-vkggv         1/1     Running   0          4m40s
cert-manager-webhook-5cbf55594c-tzvj6           1/1     Running   0          4m40s
trust-manager-5778457f48-mzkj6                  1/1     Running   0          3m38s
venafi-enhanced-issuer-7c9b979cbf-mbwfp         1/1     Running   0          3m6s
```
The `jetstack-secure` namespace how has an addtional pod called `agent-656b6b97c-24zfj` that is responsible for sending public certificate data to TLSPK dashboard. 

# 01. Request a certificate 

To create and approve a certificate manually follow the instructions [here](docs/01.create-certificate.md#creating-a-certificate)
Login to TLSPK dashboard to view the certificate data

# 02. Creating a Venafi Connection

The VenafiConnection custom resources are used to define the connection and authentication between the Venafi Control Plane and your Kubernetes cluster.

There are several ways to configure the authentication for the Venafi Control Plane. In case of TLS Protect for Datacenter or also referred to as TPP, the supported options are access-token, Username / password credentials or JWT token tied to a service account in Kubernetes. For TLS Protect Cloud (which is the as-a-service offering from Venafi), API Key is used. 
For production workloads, the supported secretless authentication using JWT or storing credentails in an external secrets store is recommeded. In this demo repo, you will find us use username and password authentication. 

To create a Venafi Connection follow the instructions [here](docs/02.create-venafi-connection.md#creating-a-venafi-connection). 
This will create two connections. One for Venafi TLS Protect Datacenter and another for TLS Protect Cloud

# 03. Creating policies for auto approval

The Venafi TLSPK Enterprise Policy Approver is an addon to define and manage `CertificateRequestPolicy` resources that provides the ability to
- define policies locally in-cluster to enforce how `CertificateRequests` are processed
- leverage Venafi plugin to locally enforce policies defined in Venafi without replicating them
- leverage `rego` plugin to leverage policies defined using Open Policy Agent 

To automatically approve certificate requests with `CertificateRequestPolicy` follow the instructions [here](docs/03.auto-approve-certs.md#create-policies-for-auto-approval)

Refresh the TLSPK dashboard to look at new data pushed by the agent. Review the data.

# 04. Pushing certificates for visibility to Venafi TLS Protect - Datacenter 

The Venafi TLSPK Enterprise certificate sync module is an addon to synchronize TLS secrets that are in cluster into a policy folder defined in Venafi for management. This allows Venafi Administrators to understand the various Certificate Authorities used for the certificates and define appropriate policies to manage compliance. Starting TLS Protect - Datacenter (or TPP as it is called) version 22.4, there is a comprehensive native discovery capability that security administrators should leverage.

To push all TLS secrets to Venafi TLS Protect - Datacenter follow the instructions [here](docs/04.cert-sync-to-venafi.md#push-certificate-data-to-venafi-trust-protection-platform)

Refresh the TLSPK dashboard to look at new data pushed by the agent. Review the data. Additionally, access the Venafi TLS Protect - Datacenter. Certificates pushed by the cert sync module will show up the folder designated for discovery.

# 05. Create identities for pods with Enterprise cert-manager CSI driver

Enterprise cert-manager CSI driver (based on the open source cert-manager CSI driver) is an addon to cert-manager to provide TLS indentities to pods running in-cluster. The identities are directly injected into the pod's ephemeral filesystem and avoids the need to create and manage TLS secrets in Kubernetes.  

Follow the instructions [here](docs/05.pod-identities-csi-driver.md#securing-pods-with-identities-using-the-venafi-jetstack-cert-manager-csi-driver) to setup Enterprise cert-manager CSI driver and validate that certs are injected into the pods.

# 06. Create identities for pods with Enterprise cert-manager SPIFFE driver

Enterprise cert-manager CSI SPIFFE driver is an addon to cert-manager to provide TLS indentities to pods running in-cluster with SPIFFE. The identities are directly injected into the pod's ephemeral filesystem and avoids the need to create and manage TLS secrets in Kubernetes.  

Follow the instructions [here](docs/06.pod-identities-csi-driver-spiffe.md#securing-pods-with-identities-using-the-venafi-jetstack-cert-manager-csi-driver-spiffe) to setup Enterprise cert-manager CSI SPIFFE driver and validate that SPIFFE SVIDS are injected into the pods

# 07. Issue certificates with Venafi Firefly

Leveraging the Venafi Firefly as a cert-manager issuer allows enterprises to configure and govern an intermediate CA from the Venafi Control Plane. Firefly issuer bootstraps itself with an intermediate CA keeps it in memory. This is critical for organizaitons that are looking for ways to avoid having to store intermediate certificate information including the privateKey as TLS secrets.  

Follow the instructions [here](docs/07.fireflyca-issuer.md#configuring-and-running-venafi-firefly)

# 08. Venafi TLSPK Enterprise cert-manager istio-csr agent to sign Istio mesh workloads 

Enterprise cert-manager istio-csr is a cert-manager addon that provides that ability to sign mesh workloads with a cert-manager issuer. Various issuers can be configured and setup as `istio-ca` for Istio. More information about istio-csr can be found [here](https://platform.jetstack.io/documentation/installation/istio-csr) 

Choose one of the following options to install and configure for your service mesh.

## 08a. Signing mesh workloads with a CA managed in Venafi TLS Protect - Datacenter 
In this scenario, we will walk through the process of configuring Venafi TLS Protect - Datacenter to manage the intermediate that will sign mesh workloads. The policy approver that's running in cluster will enforce policies defined in-cluster. Follow instructions [here](docs/08a.vtpp-istio-service-mesh.md#setting-up-venafi-trust-protection-platform-for-signing-istio-service-mesh-workloads)


## Signing mesh workloads with Venafi TLS Protect Cloud
Sign mesh workloads with Venafi TLS Protect Cloud

## Signing mesh workloads with Hashicorp Vault
Sign mesh workloads with Hashicorp Vault

## Signing mesh workloads with Google Certificate Authority Service
Sign mesh workloads with Google Certificate Authority Service
## Signing mesh workloads with AWS ACM Private Certificate Authority 
Sign mesh workloads with AWS ACM Private Certificate Authority

# 09. Issue certificates with Root CA managed in AWS KMS with cert-manager KMS Issuer  
In this scenario we will use an external issuer (AWS KMS Issuer) to sign  certificate requests.  Follow instructions [here](docs/09.certs-with-aws-kms-issuer.md#cert-manager-aws-kms-issuer-to-manage-certificates-in-cluster)

# 10. Issue certificates with cert-manager AWS ACM Private Certificate Authority Issuer
In this scenario we will use an external issuer (AWS PCA Issuer) to sign certificate requests.  Follow instructions [here](docs/10.certs-with-aws-pca-issuer.md#cert-manager-aws-pca-issuer-to-manage-certificates-in-cluster)

# 11. Manage Machine Identities using the Venafi Enhanced Issuer
In this scenatio we will create a Venafi Enhanced Issuer that would access Hashicorp Vault to get credentails required to access the Venafi Platform. `VenafiIssuer` / `VenafiClusterIssuer` resources are mapped to a `VenafiConnection` to issue and manage identities for workloads. Follow instructions [here](docs/11.certs-with-venafi-enhanced-issuer.md#cert-manager-venafi-enhanced-issuer-to-manage-certificates-in-cluster)

# 12. Examples
A set of examples , currenty covers Ingress, Openshift Ingress, Openshift Routes, Java Truststores [here](docs/12.cert-manager-samples.md#cert-manager-samples)
