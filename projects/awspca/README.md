# **Certificate issuance with AWS ACM PCA**
# This project demonstrates using AWS PCA cert-manager issuer with both IRSA and secrets.

## **Pre-requisites**

Before installing the components in cluster, make sure to setup your environment from where you plan to access the cluster.  

The `Makefile` uses environment variables from `vars.sh`. There is a template `vars-template.sh`. Use it to create `vars.sh` and set the environment variables that best suits you. 
If `Makefile` is not something you prefer to use, you can look at the targets and adapt it to your own tooling. 

**NOTE** 
There are two ways to install AWS PCA Issuer in your cluster. 
> (1) Using AWS IRSA and

> (2) Using AWS Access Key and Secret. 

Choose the one that best suits you. 


## Setting up AWS ACM PCA with IRSA

**Assumptions**
- You have followed the AWS [guide](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html) to create an IAM OIDC Identity provider for the cluster. 
- You have a created an IAM Access policy to allow access to AWS ACM PCA and have the policy ARN. There is a helper target called  `create-awspca-access-policy` if you need to create it. The policy docunent is located at [templates/pca/awspca-access-policy.json](templates/pca/awspca-access-policy.json)
- You have set the variables in `vars.sh` within the section that says "Set only if using IRSA"

Before creating an AWS ACM PCA issuer with IRSA, there are a couple of things required to be done. 
- If you don't have a policy run `make create-awspca-access-policy` 
- You need to create a IAM role that's mapped to Kubernetes service account. This can be accomplished by running the helper target `create-iam-svc-account`. Additionally there is a `delete-iam-svc-account` target for you to destroy it. The IAM service account is created using `eksctl` 

We can now create a AWS PCA Issuer using IRSA. The template for AWS PCA issuer is located at `templates/pca/aws-pca-issuer-irsa.yaml` 
The Helm install template for AWS PCA issuer is located at `templates/helm/aws-pca-issuer-irsa.yaml`. Review both the files.

**NOTE**
When a `Certificate` resource is created in the cluster, cert-manager automatically approves the `CertificateRequest` unless the approver controller is turned off. 
In this demo, we want to demonstrate a scenario where one of the `CertificateRequest` is `Denied` becuase it does not comply to a policy. If you have only installed cert-manager and not the policy-approver component in your cluster you can ignore the below step. Otherwise you should create a `CertificateRequestPolicy`. 

### Create a certificate request policy to approve certificates issued by PCA issuer
Review the policy located at [policy/cert-policy-and-rbac.yaml](policy/cert-policy-and-rbac.yaml) . It is pretty straight forward. One thing you will notice that the policy mandates provides a SPIFFE formatted URI SAN. If it's not provided or does not match the pattern the certificate request will be denied. PCA issuer also supports overriding the approver with a setting in Helm. Take a look at the PCA issuer documentation.

Run 
```
make create_certificate_policy_for_awspca
```
and you will see

```
❯ make create_certificate_policy_for_awspca
certificaterequestpolicy.policy.cert-manager.io/cert-policy-for-awspca-certs created
clusterrole.rbac.authorization.k8s.io/awspca-issuer-cluster-role created
clusterrolebinding.rbac.authorization.k8s.io/awspca-issuer-cluster-role-binding created
```

### Installing AWS PCA Issuer with IRSA
There are 3 things that happen when you run `make create-aws-pca-issuer-with-irsa`
- The Helm value file [templates/helm/aws-pca-issuer-irsa.yaml](templates/helm/aws-pca-issuer-irsa.yaml) is setup 
- PCA issuer is installed using `venctl`. If you prefer to install using standard Helm just change `install-pca` to `install-pca-helm`
- The cert-manager PCA issuer [templates/pca/aws-pca-issuer-irsa.yaml](templates/pca/aws-pca-issuer-irsa.yaml) is created

Run
```
make create-aws-pca-issuer-with-irsa
```

and you will see the following resources getting created

```
❯ make create-aws-pca-issuer-with-irsa
Generating Cyberark Helm manifests for installation
Adding repo aws-privateca-issuer https://cert-manager.github.io/aws-privateca-issuer
"aws-privateca-issuer" has been added to your repositories

Upgrading release=aws-privateca-issuer, chart=aws-privateca-issuer/aws-privateca-issuer, namespace=cyberark
Release "aws-privateca-issuer" has been upgraded. Happy Helming!
NAME: aws-privateca-issuer
LAST DEPLOYED: Wed Feb 19 20:51:44 2025
NAMESPACE: cyberark
STATUS: deployed
REVISION: 2
TEST SUITE: None

Listing releases matching ^aws-privateca-issuer$
aws-privateca-issuer	cyberark 	2       	2025-02-19 20:51:44.580249 -0600 CST	deployed	aws-privateca-issuer-v1.4.0	v1.4.0     


UPDATED RELEASES:
NAME                   NAMESPACE   CHART                                       VERSION   DURATION
aws-privateca-issuer   cyberark    aws-privateca-issuer/aws-privateca-issuer   v1.4.0          6s

awspcaissuer.awspca.cert-manager.io/awspca-issuer created
```

To validate that the issuer is created correctly, run 
```
kubectl describe AWSPCAIssuer -n sandbox  
```
to see
```
Spec:
  Arn:     arn:aws:acm-pca:us-east-1:111111111111:certificate-authority/111be1aa-1111-1111-ac71-111f1111af11
  Region:  us-east-1
Status:
  Conditions:
    Last Transition Time:  2025-02-17T21:12:46Z
    Message:               Issuer verified
    Reason:                Verified
    Status:                True
    Type:                  Ready
Events:
  Type    Reason    Age                From                     Message
  ----    ------    ----               ----                     -------
  Normal  Verified  22m (x2 over 22m)  awspcaissuer-controller  Issuer verified
```

### Request sample certificates using AWS PCA as the issuer. 
In this step we will request a couple of certificates from AWS ACM PCA
The sample certificates are located at [samples/sample-aws-pca-cert.yaml](samples/sample-aws-pca-cert.yaml)

Run,

```
make create-sample-awspca-certs
```
and you will see
```
❯ make create-sample-awspca-certs
certificate.cert-manager.io/cert1-pca-issuer.svc.cluster.local created
certificate.cert-manager.io/cert2-pca-issuer.svc.cluster.local created
certificate.cert-manager.io/cert3-pca-issuer.svc.cluster.local created
certificate.cert-manager.io/cert4-pca-issuer.svc.cluster.local created
```
Check the status of the certificates by running

```
kubectl get Certificate -n sandbox 
```
and you will see
```
NAME                                     READY   SECRET                                   AGE
cert1-pca-issuer.svc.cluster.local       True    cert1-pca-issuer.svc.cluster.local       1m
cert2-pca-issuer.svc.cluster.local       False   cert2-pca-issuer.svc.cluster.local       1m
cert3-pca-issuer.svc.cluster.local       True    cert3-pca-issuer.svc.cluster.local       1m
cert4-pca-issuer.svc.cluster.local       True    cert4-pca-issuer.svc.cluster.local       1m
```

**NOTE**  `cert2-pca-issuer.svc.cluster.local` is not Ready. To find out why it was not issued run

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

## Setting up AWS ACM PCA with Access Key

Set the environment variables in `vars.sh` to set the access key and secret. 
Review the target `create-aws-pca-issuer-access-key` to see what it does. It's simple. 
- The Helm template is located at [templates/helm/aws-pca-issuer.yaml](templates/helm/aws-pca-issuer.yaml)
- The template for AWS PCA issuer is located at [templates/pca/aws-pca-issuer.yaml](templates/pca/aws-pca-issuer.yaml) and the corresponding secret is located at [templates/pca/aws-secret.yaml](templates/pca/aws-secret.yaml)

Run

```
make create-aws-pca-issuer-access-key
```

Create the certificate policy and sample certs  (instructions above) 

## Cleanup

Run `make clean` to clean all resources you've created.