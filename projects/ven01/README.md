# This project demonstrates using Venafi to issuer certificates in cluster. Additonally includes samples to use AWS PCA issuer with both IRSA and secrets.

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
- Open vars.sh and set the environemnt variables
- Set VEN_SERVER_URL to the URL used in the `vcert` command
- Set VEN_ACCESS_TOKEN to the value of `access_token` returned above.
- The VEN_PRIVATE_CA1 is the policy folder from which you will be issuing certificates. Replace the value with the policy folder that you intend to use. 
- The VEN_TPP_CA_BUNDLE_PEM_FILE is relevant if your TPP server `venafi.example.com` uses a private CA. To make sure you have a complete setup with trust store setup, download the certificate chain of your TPP server and save it as a pem file. Provide the path to the PEM file. 

NOTE: A simple way (my simple way) is to just hit the TPP URL using firefox and downloading the certificate and chain as PEM. You can choose to download it the best way that works for you. 

# **Cluster Setup**

**NOTE** There is no registry access secret in this repo. You should have been provided one or you have the ability to generate one from the product. 

Copy the registry secret YAML 
```
cp your-registry-secret.yaml registry/venafi_registry_secret.yaml
```

Start with cluster setup only after you have completed the Venafi configuration and setup the environment variables. 

NOTE: Before you run any `make <target>` review what the target does. 

## **STEP 0**

`venctl` is the CLI used for installing / configuring the Helm charts required to operationalize Venafi in cluster. There are other ways to install the components (using Helm charts directly)

The `Makefile` has a target to download `venctl`. Run,

```
make install-venctl
```

You can run the command `install-venctl` to upgrade your `venctl` CLI at any time. 

**READ THIS** There are a total of 6 steps to perform to configure and install the venafi components in cluster. This includes AWS PCA Issuer. The steps below assume that you will use AWS ACCESS KEY and SECRET to configure the AWS PCA Issuer. If your preference is to use AWS IRSA skip to section [Using AWSPCA Issuer with IRSA](#using-irsa-for-aws-pca-issuer)

## **STEP 1**

Step 1 is essentially a setup target to create a few things
- temporary directory called `artifacts` where configs will be generated and run from
- Couple of namespaces (venafi, sandbox) is created
- A image registry pull secret is created in the venafi namespace 
- The `ConfigMap` that holds the Venafi server trust anchor is created 
- Couple of helm values file from `templates/helm` directory is staged in `artifacts` directory  

**NOTE** Make sure you have a valid image pull registry secret. If you are unable to pull images directly from Venafi's OCI registry, all Venafi container images will need to be pulled and mirrored in your artifactory/registry. This section assumes you have the ability to pull container images from Venafi's private OCI registry. Mirroring images is common and something we expect will happen for your production setups.

Run 
```
make step1
```
Among other things, you will see the following in the console. You can run `make step1` as many times as you want if you see any failures the first time. 

```
namespace/venafi created
namespace/sandbox created
Credentials for venafi registry
secret/venafi-image-pull-secret created
configmap/venafi-tpp-ca-bundle created
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
The generated manifest file can be found in the file `artifacts/venafi-install/venafi-manifests.yaml`

## **STEP 3**

Using the manifest file that was generated in the previous step, we will install the required components in the cluster. To do this simply run,
```
make step3
```
This step will take a few minutes to complete and you will be able to see the progress of the installation of various components. On completion you will see

```
UPDATED RELEASES:
NAME                         CHART                                       VERSION   DURATION
venafi-connection            venafi-charts/venafi-connection             v0.0.18         8s
cert-manager                 venafi-charts/cert-manager                  v1.14.2        44s
approver-policy-enterprise   venafi-charts/approver-policy-enterprise    v0.13.0        16s
venafi-enhanced-issuer       venafi-charts/venafi-enhanced-issuer        v0.11.0        21s
```

While using `venctl` is the simplest way to install and manage all Venafi components, each component has it's own Helm chart and can be individually installed and managed on your own. 

You can additionally validate that all the pods are in `Running` state by running
`kubectl get pods -n venafi` to see

```
NAME                                           READY   STATUS    RESTARTS   AGE
cert-manager-9f9b9c886-rxq2b                   1/1     Running   0          2m47s
cert-manager-approver-policy-586794d79-ptxtr   1/1     Running   0          2m10s
cert-manager-cainjector-946945c55-8vk8c        1/1     Running   0          2m47s
cert-manager-webhook-cd4cb8bd7-27tll           1/1     Running   0          2m47s
venafi-enhanced-issuer-7664f88db7-85khw        1/1     Running   0          2m9s
venafi-enhanced-issuer-7664f88db7-ztphk        1/1     Running   0          2m9s
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
You can inspect the `CertificateRequestPolicy` by running `kubectl get crp` to see
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

# **Testing certificate issuance with AWS ACM PCA**

**NOTE** There are two choices to install and test certificate issuance with AWS ACM PCA. First with AWS IRSA and the second using AWS Access Key and Secret. Choose the one that best suits you. The component installation has been separated only to validate both the usecases. If there is only one mode of installation, `awspca-issuer` can be part of the standard Venafi packaged installation. 
Choose either 7A or 7B

## STEP 7A - Setting up AWS ACM PCA with IRSA

**Assumptions**
- You have followed the AWS [guide](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html) to create an IAM OIDC Identity provider for the cluster. 
- You have a created an IAM Access policy to allow access to AWS ACM PCA and have the policy ARN. There is a target `create-awspca-access-policy` if you need to create it. The policy docunent is located at `templates/pca/awspca-access-policy.json`
- You have set the variables in `vars.sh` within the section that says "Set only if using IRSA"

Before creating an AWS ACM PCA issuer with IRSA, there are a couple of things required to be done. 
- If you don't have a policy run `make create-awspca-access-policy` to create a policy to allow access to your PCA and note the policy ARN. This is required to be set in `vars.sh`
- You need to create a IAM role that's mapped to Kubernetes service account. This can be accomplished by running `create-iam-svc-account`


We can now create a AWS PCA Issuer using IRSA. The template for AWS PCA issuer is located at `templates/pca/aws-pca-issuer-irsa.yaml` 
The Helm install template for AWS PCA issuer is located at `templates/helm/aws-pca-issuer-irsa.yaml`

Run
```
make step7a
```

and you will see the following resources getting created
```
certificaterequestpolicy.policy.cert-manager.io/cert-policy-for-awspca-certs created
clusterrole.rbac.authorization.k8s.io/awspca-issuer-cluster-role created
clusterrolebinding.rbac.authorization.k8s.io/awspca-issuer-cluster-role-binding created
Release "aws-privateca-issuer" does not exist. Installing it now.
NAME: aws-privateca-issuer
LAST DEPLOYED: Fri Mar  1 13:09:29 2024
NAMESPACE: venafi
STATUS: deployed
REVISION: 1
TEST SUITE: None
awspcaissuer.awspca.cert-manager.io/awspca-issuer created
```
To validate that the issuer is created correctly, run 
```
kubectl describe AWSPCAIssuer -n sandbox  
```
to see
```
Status:
  Conditions:
    Last Transition Time:  2024-03-01T19:12:31Z
    Message:               Issuer verified
    Reason:                Verified
    Status:                True
    Type:                  Ready
Events:
  Type    Reason    Age                From                     Message
  ----    ------    ----               ----                     -------
  Normal  Verified  22m (x2 over 22m)  awspcaissuer-controller  Issuer verified
```

## STEP 7B - Setting up AWS ACM PCA with Access Key

**NOTE** Make sure VEN_AWS_PCA_ARN VEN_AWS_PCA_REGION VEN_AWS_PCA_ACCESS_KEY VEN_AWS_PCA_SECRET_ACCESS_KEY values are set. 

In this step we will create a AWS PCA Issuer using access key. The template for AWS PCA issuer is located at `templates/pca/aws-pca-issuer.yaml` and the corresponding secret is located at `templates/pca/aws-secret.yaml`

The Helm install template for AWS PCA with access key is located at `templates/helm/aws-pca-issuer.yaml`

Run
```
make step7b
```
and you will see the following resources getting created
```
secret/aws-pca-secret created
certificaterequestpolicy.policy.cert-manager.io/cert-policy-for-awspca-certs created
clusterrole.rbac.authorization.k8s.io/awspca-issuer-cluster-role created
clusterrolebinding.rbac.authorization.k8s.io/awspca-issuer-cluster-role-binding created
Release "aws-privateca-issuer" does not exist. Installing it now.
NAME: aws-privateca-issuer
LAST DEPLOYED: Fri Mar  1 13:12:11 2024
NAMESPACE: venafi
STATUS: deployed
REVISION: 1
TEST SUITE: None
awspcaissuer.awspca.cert-manager.io/awspca-issuer created
```
To validate that the issuer has been created run
```
kubectl describe AWSPCAIssuer -n sandbox
```
to see
```
Status:
  Conditions:
    Last Transition Time:  2024-02-29T19:26:02Z
    Message:               Issuer verified
    Reason:                Verified
    Status:                True
    Type:                  Ready
Events:
  Type    Reason    Age                    From                     Message
  ----    ------    ----                   ----                     -------
  Normal  Verified  8m15s (x2 over 8m15s)  awspcaissuer-controller  Issuer verified
```

## **STEP 8**
In this step we will request a couple of certificates from AWS ACM PCA
The sample certificates are located at `samples/sample-aws-pca-cert.yaml`

Run,

```
make step8
```
and you will see
```
certificate.cert-manager.io/cert1-pca-issuer.svc.cluster.local created
certificate.cert-manager.io/cert2-pca-issuer.svc.cluster.local created
```
Check the status of the certificates by running

```
kubectl get Certificate -n sandbox 
```
and you will see `cert2-pca-issuer.svc.cluster.local` is not Ready. To find out why it was not issued run

```
kubectl describe Certificate cert2-pca-issuer.svc.cluster.local  -n sandbox
```
and you will see
```
Events:
  Type     Reason                  Age   From                                       Message
  ----     ------                  ----  ----                                       -------
  Normal   Issuing                 1m   cert-manager-certificates-trigger          Issuing certificate as Secret does not exist
  Normal   Generated               1m   cert-manager-certificates-key-manager      Stored new private key in temporary Secret resource "cert2-pca-issuer.svc.cluster.local-txzf9"
  Normal   Requested               1m   cert-manager-certificates-request-manager  Created new CertificateRequest resource "cert2-pca-issuer.svc.cluster.local-1"
  Warning  policy.cert-manager.io  1m   cert-manager-certificates-issuing          The certificate request has failed to complete and will be retried: No policy approved this request: [cert-policy-for-awspca-certs: spec.allowed.uris.required: Required value: true]
```
The policy does not allow requesting a certificate request without a URI SAN. 

To inspect the other valid certificate run,

```
kubectl get secret -n sandbox cert1-pca-issuer.svc.cluster.local -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text | HEAD
```
and you will see the Issuer information matching your AWS ACM PCA.

# **Discovering all certificates in Venafi**
Doc TBD