# Getting started with Venafi TLS Protect For Kubernetes

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
- If you are on an openshift environemnt run `make update-openshift-venafi-scc`
- If you are bringing your own cluster then simply run `make cluster-addons` 
- Jetstack cert-manager along with the policy approver addon, trust and the venafi enhanced issuer will be added to the cluster

## Validating your cluster
- Check if the components of Jetstack Secure are installed and running.
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

# Connecting the cluster to Venafi Jetstack Secure Dashboard
- Log back into Jetstack Secure https://platform.jetstack.io and click on Clusters.
- For specific instructions and screenshots click [here](docs/jetstack-secure.md#connecting-a-cluster-to-jetstack-secure)
- Validate that the Jetstack Secure Agent has been installed and running in the cluster.
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
The `jetstack-secure` namespace how has an addtional pod called `agent-656b6b97c-24zfj` that is responsible for pushing the certificates to Jetstack Secure dashboard. 

# 01. Request a certificate 

To create and approve a certificate manually follow the instructions [here](docs/01.create-certificate.md#creating-a-certificate)
Login to Jetstack Secure dashboard to view the certificate data

# 02. Creating a Venafi Connection

The VenafiConnection custom resources are used to configure the connection and authentication between the Venafi Control Plane and your Kubernetes cluster.

The simplest way of authentication to the Venafi control plane is using the Venafi TPP access-token, Venafi-TPP username and password or Venafi-as-a-Service API Key stored as a Kubernetes secrert. The Venafi connection supports secretless authentication using JWT or storing credentails in an external secrets engine like Vault. In this sample we will use the username and password authentication. 

To create a venafi connection follow the instructions [here](docs/02.create-venafi-connection.md#creating-a-venafi-connection)

# 03. Creating policies for auto approval

The Venafi Jetstack Enterprise Policy Approver is an enterprise addon to define and manage `CertificateRequestPolicy` resources that provides the ability to
- define policies locally in-cluster that enforces how `CertificateRequests` are processed
- leverage Venafi plugin to locally enforce policies defined in Venafi without replicating them
- leverage `rego` plugin to leverage policies defined using Open Policy Agent 

To automatically approve certificate requests with `CertificateRequestPolicy` follow the instructions [here](docs/03.auto-approve-certs.md#create-policies-for-auto-approval)

Refresh the Jetstack Secure dashboard to look at new data pushed by the agent. Review the data.

# 04. Pushing certificates for visibility to Venafi Trust Protection Platform 

The Venafi Jetstack Enterprise certificate sync module is an enterprise addon to synchronize TLS secrets that are in cluster into a policy folder defined in Venafi for management. This allows Venafi Administrators to understand the various Certificate Authorities used for the certificates and define appropriate policies to manage compliance. 

To setup the ability to push all TLS secrets to Venafi Trust Protection Platform follow the instructions [here](docs/04.cert-sync-to-venafi.md#push-certificate-data-to-venafi-trust-protection-platform)

Refresh the Jetstack Secure dashboard to look at new data pushed by the agent. Review the data. Additionally, access the Venafi Trust Protection Platform. Certificates pushed by the cert sync module will show up the folder designated for discovery.

# 05. Create identities for pods with Jetstack cert-manager CSI driver

Jetstack cert-manager CSI driver is an addon to cert-manager to provide TLS indentities to pods running in-cluster. The identities are directly injected into the pod's tmp filesystem thereby avoiding the need to create and manage TLS secrets in Kubernetes.  

Follow the instructions [here](docs/05.pod-identities-csi-driver.md#securing-pods-with-identities-using-the-venafi-jetstack-cert-manager-csi-driver) to setup Jetstack cert-manager CSI driver and validate that certs are injected into the pods.

# 06. Create identities for pods with Jetstack cert-manager SPIFFE driver

Jetstack cert-manager CSI SPIFFE driver is an addon to cert-manager to provide TLS indentities to pods running in-cluster using SPIFFE. The identities are directly injected into the pod's tmp filesystem thereby avoiding the need to create and manage TLS secrets in Kubernetes.  

Follow the instructions [here](docs/06.pod-identities-csi-driver-spiffe.md#securing-pods-with-identities-using-the-venafi-jetstack-cert-manager-csi-driver-spiffe) to setup Jetstack cert-manager CSI SPIFFE driver and validate that SPIFFE SVIDS are injected into the pods

# 07. Issue certificates with an issuer running outside the cluster

The Venafi Jetstack Enterprise issuer for cert-manager provides a mechanism for organizations to run an issuer either in-cluster or isolated from the cluster. The isolated issuer bootstraps itself with an intermediate CA issued by Venafi and keeps it in memory. This is critical for organizaitons that are looking for ways to avoid having to store certificate information including the privateKey as TLS secrets. 

Follow the instructions [here](docs/07.isolated-issuer.md#configuring-and-running-venafi-jetstack-secure-isolated-issuer)

# 08. Venafi Jetstack Secure cert-manager istio-csr agent to sign Istio mesh workloads 

Jetstack cert-manager istio-csr is a cert-manager addon that provides that ability to sign mesh workloads with a cert-manager issuer. Various issuers can be configured and setup as `istio-ca` for Istio. More information about istio-csr can be found [here](https://platform.jetstack.io/documentation/installation/istio-csr) 

Choose one of the following options to install and configure for your service mesh.

## 08a. Signing mesh workloads with Venafi Trust Protection Platform 
In this scenario, we will walk through the process of configuring Venafi Trust Protection Platform to manage the intermediate that will sign mesh workloads. The policy approver that's running in cluster will enforce policies defined in-cluster. Follow instructions [here](docs/08a.vtpp-istio-service-mesh.md#setting-up-venafi-trust-protection-platform-for-signing-istio-service-mesh-workloads)


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

# 11. Issue Machine Identities using the Venafi Enhanced Issuer
In this scenatio we will create a venafi enhanced issuer that would access Hashi Vault to get credentails required to access the Venafi API's. We will use Venafi Trust Protection Platfor/Venafi As A Service to sign a certificate request. Follow instructions [here](docs/11.certs-with-venafi-enhanced-issuer.md#cert-manager-venafi-enhanced-issuer-to-manage-certificates-in-cluster)

# 12. Examples
A set of examples , currenty covers Ingress, Openshift Ingress, Openshift Routes, Java Truststores [here](docs/12.cert-manager-samples.md#cert-manager-samples)
