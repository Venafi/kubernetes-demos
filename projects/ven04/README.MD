# This project demonstrates using CyberArk Certificate Manager - SaaS to issue certificates in cluster. 

# **Pre-requisites**

Before installing the CyberArk Certificate Manager for Kubernetes components in cluster, make sure to setup the environment 

The `Makefile` uses environment variables from `vars.sh`. If `Makefile` is not something you prefer to use, you can look at the targets and adapt it to your own tooling. 

## **Setting up your  environment**

Make sure you have access to CyberArk Certificate Manager Saas. 
- Access your tenant, go to Settings -> Teams and create a new Team. If you already have a team, you don't need to create a new one. 
- For the purposes for this workflow let's call the team "platform-admin" 
- Assign the System Admin role to the team 
- Login to your tenant and find the APIKey. Copy it 

Once you have an api-key,

- Copy `vars-template.sh` to `vars.sh`
- Open vars.sh and set the environment variables
- Set CYBR_CLOUD_API_KEY to the value of `apiKey` from your tenant. This is required to create the required service accounts to pull Venafi enterprise images, register a cluster, etc. 
- Set CYBR_TEAM_NAME to the team name. For eg `platform-admin` 
- The CYBR_ZONE_PRIVATE_CA is the path to the application issuing template. As the variable name suggests, let's set the value to a template that can issue certificates using a private CA. For eg. "My-Business-App\\my-private-ca-template". If you need help configuring a Certificate Authority and an Issuing Template, follow the product documentation. 
-  The CYBR_ZONE_PRIVATE_CA is the path to the application issuing template. As the variable name suggests, let's set the value to a template that can issue certificates using a public CA. For eg. "My-Business-App\\my-public-ca-template". If you need help configuring a Certificate Authority and an Issuing Template, follow the product documentation. 
- The CYBR_DOMAIN_FOR_SAMPLE_APP is for you to set a domain that you have access to. For e.g `example.com` Public CA cannot issue certificates to a domain to that you do not manage. 


# **Cluster Setup**

**NOTE** Proceed only if you have the entitlement to create an OCI registry secret to access CyberArk's private registry  

NOTE: Before you run any `make <target>` review what the target does. 

## **STEP 0**

`venctl` is the CLI used for installing / configuring the Helm charts required to run the components in cluster. There are other ways to install the components (using Helm charts directly)

The `Makefile` has a target to download `venctl`. Run,

```
make install-venctl
```

You can run the command `install-venctl` to upgrade your `venctl` CLI at any time. 


## **STEP 1**

Step 1 is essentially a setup target to create a few things
- temporary directory called `artifacts` where configs will be generated and run from
- Couple of namespaces (cyberark, sandbox) is created
- A image registry pull secret is created in the cyberark namespace 

**NOTE**  If you are unable to pull images directly from CyberArk's OCI registry, all CyberArk container images will need to be pulled and mirrored in your artifactory/registry. This section assumes you have the ability to pull container images from CyberArk's private OCI registry. Mirroring images is common and something we expect will happen for your production setups.

Run 
```
make init-cloud
```
Among other things, you will see the following in the console. 

```
...
Service account was created successfully....
namespace/cyberark created
namespace/sandbox created
Credentials for venafi registry
secret/venafi-image-pull-secret created
Credentials for certificate discovery
secret/agent-credentials created
```

## **STEP 2**

`venctl` is the CLI for managing the resources in Kubernetes. In this step we will generate the requrired manifests that needs to be installed. 

Run 
```
make generate-venafi-manifests
```
The output of this will simply say 
```
Generating Venafi Helm manifests for installation
```
The generated manifest file can be found in the file `artifacts/cyberark-install/venafi-manifests.yaml` Feel free to review the file. 

## **STEP 3**

Using the manifest file that was generated in the previous step, we will install the required components in the cluster. To do this simply run,
```
make install
```
This step will take a few minutes to complete and you will be able to see the progress of the installation of various components. On completion you will see

```
UPDATED RELEASES:
NAME                         NAMESPACE   CHART                                      VERSION   DURATION
venafi-connection            cyberark    venafi-charts/venafi-connection            v0.4.0          2s
cert-manager                 cyberark    venafi-charts/cert-manager                 v1.17.1        30s
approver-policy-enterprise   cyberark    venafi-charts/approver-policy-enterprise   v0.20.0        16s
venafi-enhanced-issuer       cyberark    venafi-charts/venafi-enhanced-issuer       v0.15.0        20s
venafi-kubernetes-agent      cyberark    venafi-charts/venafi-kubernetes-agent      v1.4.1         31s
```

While using `venctl` is the simplest way to install and manage all the components, each component has it's own Helm chart and can be individually installed and managed on your own. 

You can additionally validate that all the pods are in `Running` state by running
`kubectl get pods -n cyberark` to see

```
NAME                                            READY   STATUS    RESTARTS   AGE
cert-manager-86df8fd8c5-fm5z9                   1/1     Running   0          97s
cert-manager-approver-policy-86c9f87b69-5gjpr   1/1     Running   0          68s
cert-manager-cainjector-665fc48f57-ckb2t        1/1     Running   0          97s
cert-manager-webhook-59545d69b-nmj57            1/1     Running   0          97s
venafi-enhanced-issuer-69c56f45f-79w8n          1/1     Running   0          68s
venafi-enhanced-issuer-69c56f45f-8h5tk          1/1     Running   0          68s
venafi-kubernetes-agent-5cb96f8877-knlbb        1/1     Running   0          68s
```

# **Testing certificate issuance**

## **STEP 4**
A  `CertificateRequestPolicy` created by the platform admin who has access to Kubernetes allows automatically approving a policy that satisfies the constraints. The policy is locally enforced in the cluster and can also optionally refer to the central policy defined in the Venafi platform. Both central and local policy must pass for request to be automatically approved. 

Review the certificate request resource in `templates/common/cert-policy-and-rbac.yaml` to get an idea of how policies are defined. 

Before we test issuing a certificate let's create a policy by running ,
```
make create-certificate-policy
```
Policy and the required RBAC's are created and you should see the following output 

```
certificaterequestpolicy.policy.cert-manager.io/cert-policy-for-venafi-certs created
clusterrole.rbac.authorization.k8s.io/venafi-issuer-cluster-role created
clusterrolebinding.rbac.authorization.k8s.io/venafi-issuer-cluster-role-binding created
```
You can inspect the `CertificateRequestPolicy` by running `kubectl get crp cert-policy-for-venafi-certs` to see
```
NAME                           READY   AGE
cert-policy-for-venafi-certs   True    61s
```
Optionally describe the resource to see more details. 


## **STEP 5**
We will now create the Venafi Certificate Issuer in the cluster. This step assumes `vars.sh` has the correct values

You can inspect the resources that will be created by looking at `templates/cloud/*.yaml`
Run,
```
make create-issuers
```
Running this target will create 2 issuers. One issuer configured to use the public CA and another one configured to use a private CA. Review the target to seperately create the resources or adjust as needed. You will see the below output when you run `create-issuers` 

```
clusterrole.rbac.authorization.k8s.io/read-creds-secret-role-for-venafi-connection created
clusterrolebinding.rbac.authorization.k8s.io/read-creds-secret-role-for-venafi-connection created
secret/venafi-cloud-credentials created
venaficonnection.jetstack.io/venafi-connection created
venaficlusterissuer.jetstack.io/venafi-privateca-cluster-issuer created
venaficlusterissuer.jetstack.io/venafi-publicca-cluster-issuer created
```

If everything has worked well so far, running `kubectl get VenafiClusterIssuer` should print the following

```
NAME                              READY   REASON    MESSAGE                         LASTTRANSITION   OBSERVEDGENERATION   GENERATION   AGE
venafi-privateca-cluster-issuer   True    Checked   Succeeded checking the issuer   21s              1                    1            22s
venafi-publicca-cluster-issuer    True    Checked   Succeeded checking the issuer   21s              1                    1            22s
```
Optionally describe the resources to review additonal details. 

**NOTE**: Everything you did until now is ONE-TIME configuration for every cluster you create/onboard.

We are now ready to request a certificate. Your developers now have the ability to create `Certificate` resources and use it in various Kubernetes resources (Ingress, Pod, Gateway, etc..)

## **STEP 6**
We will create two `Certificates`. The templates to create the sample certificates are located in `templates/certificates` directory.  

**IMPORTANT**  The information in `sample-***-cert.yaml` will be used for creating the CSR and sent to Venafi. If your policy does not allow any of the values then change the resource accordingly. For e.g the sample certificate uses `svc.cluster.local` for the common and DNS names. That may not be in the allowed list of your Venafi policy. Similarly, if you have locked the other subject properties, change it as needed.  

To run this step execute,
```
make create-certs
```
to see
```
certificate.cert-manager.io/2713563004.svc.cluster.local created
certificate.cert-manager.io/2713563004.foo.example.com created
```

To check if the `Certificate` was successfully issued run
```
kubectl get Certificate -n sandbox
```
and you should see
```
NAME                           READY   SECRET                         AGE
2713563004.foo.example.com     True    2713563004.foo.example.com     47s
2713563004.svc.cluster.local   True    2713563004.svc.cluster.local   47s
```

The status `Ready=True` indicates that the certificate was successfully issued. If you see `False` then do the following

Run `kubectl get CertificateRequests -n sandbox`
Find the name of the `CertificateRequest` resource and describe it to see what the error is and fix the certificate resource. 
You can run `make remove-certs` to delete and retry 

To inspect the certificate run 
```
kubectl get secret -n sandbox 2713563004.svc.cluster.local -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text | HEAD
```

# **Discovering all certificates in Venafi**
With the agent installed the cluster, you can access the CyberArk Certificate Manager tenant and access Installations->Kubernetes Clusters to look at the discovered certificates. 

# Cleanup
Simply run `make clean` to delete all resources and uninstall the components in the cluster.