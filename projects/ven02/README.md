# This project demonstrates using Venafi to issuer certificates in cluster. 

# **Pre-requisites**

Before installing the Venafi components in cluster, make sure to setup the environment 

The `Makefile` uses environment variables from `vars.sh`. If `Makefile` is not something you prefer to use, you can look at the targets and adapt it to your own tooling. 

## **Setting up your Venafi environment**

Make sure you have a Venafi TPP username and password to work with. 
- Login to your Venafi Platform 
- In the platform find API Integrations. There you will find a pre-created API integration called `cert-manager.io` You can use this or create new one. If you choose to use the existing one, click on it and the Venafi user. This allows the Venafi user access to the `client-id` 
- To issue certificates from Venafi in Kubernetes, we need to connect a Kubernetes cluster and your TPP. This is done via an `access_token` 
- Getting an access token is simple and requires you to run the `vcert` command from your terminal / windows prompt. 

Run 
```
vcert getcred --username <replace-with-user-name> \
		           --password <replace-with-password> \
				   -u https://venafi.example.com/vedsdk \
				   --client-id cert-manager.io \
				   --scope "certificate:manage,revoke" \
				   --format json
```
The command will return output that should look like below
```
{
    "access_token": "your-token",
    "expires": 1740175421,
    "identity": "local:{your-identity}",
    "refresh_token": "<your-refresh-token>",
    "scope": "certificate:manage,revoke",
    "token_type": "Bearer"
}
```
Once you have an access-token,

- Copy `vars-template.sh` to `vars.sh`
- Open vars.sh and set the environment variables
- Set VEN_SERVER_URL to the URL used in the `vcert` command
- Set VEN_ACCESS_TOKEN to the value of `access_token` returned above.
- The VEN_PRIVATE_CA1 is the policy folder from which you will be issuing certificates. Replace the value with the policy folder that you intend to use. 
- The VEN_TPP_CA_BUNDLE_PEM_FILE is relevant if your TPP server `venafi.example.com` uses a private CA. To make sure you have a complete setup with trust store setup, download the certificate chain of your TPP server and save it as a pem file. Provide the path to the PEM file. 
- Set VEN_CLOUD_API_KEY with your API key from Venafi Cloud. This is required to create the required service account to pull Venafi enterprise images. 

Additionally, log your Venafi cloud tenant and create a Team. You can name the team anything you prefer but the scripts assume the name "InfoSec". If your team name is different you will see an error when service accounts are created. Change the service account creation command to include the correct team name. 

# **Cluster Setup**

**NOTE** Proceed only if you have the entitlement to create an OCI registry secret to access Venafi's private registry  

Start with cluster setup only after you have completed the Venafi configuration and setup the environment variables. 

NOTE: Before you run any `make <target>` review what the target does. 

## **STEP 0**

`venctl` is the CLI used for installing / configuring the Helm charts required to operationalize Venafi in cluster. There are other ways to install the components (using Helm charts directly)

The `Makefile` has a target to download `venctl`. Run,

```
make install-venctl
```

You can run the command `install-venctl` to upgrade your `venctl` CLI at any time. 


## **STEP 1**

Step 1 is essentially a setup target to create a few things
- temporary directory called `artifacts` where configs will be generated and run from
- Couple of namespaces (venafi, sandbox) is created
- A image registry pull secret is created in the venafi namespace 
- The `ConfigMap` that holds the Venafi server trust anchor is created 
- Couple of helm values file from `templates/helm` directory is staged in `artifacts` directory  

**NOTE**  If you are unable to pull images directly from Venafi's OCI registry, all Venafi container images will need to be pulled and mirrored in your artifactory/registry. This section assumes you have the ability to pull container images from Venafi's private OCI registry. Mirroring images is common and something we expect will happen for your production setups.

Run 
```
make step1
```
Among other things, you will see the following in the console. You can run `make step1` as many times as you want if you see any failures the first time. 

```
...
Service account was created successfully....
namespace/venafi created
namespace/sandbox created
Credentials for venafi registry
secret/venafi-image-pull-secret created
secret/venafi-tpp-server-cert created
```

## **STEP 2**

`venctl` is the CLI for managing Venafi Kubernetes resources. In this step we will generate the requrired manifests that needs to be installed. 

Run 
```
make step2 
```
The output of this will simply say 
```
Generating Venafi Helm manifests for installation
```
The generated manifest file can be found in the file `artifacts/venafi-install/venafi-manifests.yaml` Feel free to review the file. 

## **STEP 3**

Using the manifest file that was generated in the previous step, we will install the required components in the cluster. To do this simply run,
```
make step3
```
This step will take a few minutes to complete and you will be able to see the progress of the installation of various components. On completion you will see

```
UPDATED RELEASES:
NAME                         CHART                                      VERSION   DURATION
venafi-connection            venafi-charts/venafi-connection            v0.0.20         1s
cert-manager                 venafi-charts/cert-manager                 v1.14.4        26s
venafi-enhanced-issuer       venafi-charts/venafi-enhanced-issuer       v0.13.3        23s
approver-policy-enterprise   venafi-charts/approver-policy-enterprise   v0.15.0        23s
trust-manager                venafi-charts/trust-manager                v0.9.2         17s
```

While using `venctl` is the simplest way to install and manage all Venafi components, each component has it's own Helm chart and can be individually installed and managed on your own. 

You can additionally validate that all the pods are in `Running` state by running
`kubectl get pods -n venafi` to see

```
NAME                                            READY   STATUS    RESTARTS   AGE
cert-manager-5ff95778f4-ntwmd                   1/1     Running   0          107s
cert-manager-approver-policy-5bb776797f-t6kvm   1/1     Running   0          82s
cert-manager-cainjector-6b9c5fffd5-k4vbc        1/1     Running   0          107s
cert-manager-webhook-84545cd465-scr9x           1/1     Running   0          107s
trust-manager-667ddb8554-7r697                  1/1     Running   0          59s
venafi-enhanced-issuer-7798995846-4djzd         1/1     Running   0          82s
venafi-enhanced-issuer-7798995846-vk6xc         1/1     Running   0          82s
```

# **Testing certificate issuance with Venafi**

## **STEP 4**
Certificate Requests are not fulfilled unless the request is explicity approved. `CertificateRequestPolicy` allows automatically approving a policy that satisfies the constraints. The policy is locally enforced in the cluster and can also optionally refer to the central policy defined in the Venafi platform. Both central and local policy must pass for request to be automatically approved. 

Review the certificate request resource in `templates/common/cert-policy-and-rbac.yaml` to get an idea of how policies are defined. 

Before we test issuing a certificate let's create a policy by running ,
```
make step4
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
We will now create the Venafi Certificate Issuer in the cluster. This step assumes `vars.sh` has the correct values for `VEN_SERVER_URL`, `VEN_ACCESS_TOKEN`, `VEN_PRIVATE_CA1`

You can inspect the resources that will be created by looking at `templates/dc/*.yaml`
Run,
```
make step5
```
Running this target will create the following resources
```
clusterrole.rbac.authorization.k8s.io/read-creds-secret-role-for-venafi-connection created
clusterrolebinding.rbac.authorization.k8s.io/read-creds-secret-role-for-venafi-connection created
secret/venafi-tpp-credentials created
venaficonnection.jetstack.io/venafi-tpp-connection created
venaficlusterissuer.jetstack.io/venafi-tpp-cluster-issuer created
```

If everything has worked well so far, running `kubectl get VenafiClusterIssuer` should print the following

```
NAME                        READY   REASON    MESSAGE                         LASTTRANSITION   OBSERVEDGENERATION   GENERATION   AGE
venafi-tpp-cluster-issuer   True    Checked   Succeeded checking the issuer   28s              1                    1            34s
```
We are now ready to request a certificate. 

**NOTE**: All the steps until now is one time configuration. You will perform these for each cluster you want to onboard with Venafi certificate services. 

## **STEP 6**
Let's now do a quick test to request a certificate. 
The sample certificate resource is in `samples/sample-cert.yaml`

**IMPORTANT**  The information in `sample-cert.yaml` will be used for creating the CSR and sent to Venafi. If your policy does not allow any of the values then change the resource accordingly. For e.g the sample-cert uses `svc.cluster.local` for the common and DNS names. That may not be in the allowed list of your Venafi policy. Similarly, if you have locked the other subject properties, change it as needed.  

To run this step execute,
```
make step6
```
to see
```
certificate.cert-manager.io/sample-cert01.svc.cluster.local created
```

To check if the `Certificate` was successfully issued run
```
kubectl get Certificate -n sandbox
```
and you should see
```
NAME                              READY   SECRET                            AGE
sample-cert01.svc.cluster.local   True    sample-cert01.svc.cluster.local   27s
```

The status `Ready=True` indicates that the certificate was successfully issued. If you see `False` then do the following

Run `kubectl get CertificateRequests -n sandbox`
Find the name of the `CertificateRequest` resource and describe it to see what the error is and fix the certificate resource. 
You can run `make remove-cert` to delete and retry 

To inspect the certificate run 
```
kubectl get secret -n sandbox sample-cert01.svc.cluster.local -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text | HEAD
```

# **Discovering all certificates in Venafi**
Doc TBD