# CyberArk Certificate Manager with Kong Mesh
This README has instructions to install and configure CyberArk Certificate Manager for Kubernete components. 

## Requirements  
- You have access to the [CyberArk Certificate Manager](!https://ui.venafi.cloud) and have the entitlements to use 
   - CyberArk Certificate Manager
   - CyberArk Certificate Manager for Kubernetes
   - CyberArk Workload Identity Manager

## Pre-requisites 
Before you start, there are some requirements to setup the environment.
The demos use a `Makefile` for all operations. Always review the target you are asked to execute. If you prefer to adapt it to another tool, please do. 

- Install the command line tool that we will be using for installing and configuring Venafi components in cluster. You can run `make install-venctl` to do this. Running this comamnd again, will attempt an upgrade if one is available. `venctl` is frequently updated with new capabilities so use `make install-venctl` frequently. 

- Review the file `versions.sh`. You don't need to change it unless you want to pin a component to a specific version. This repo will likely be pinned to latest versions of all the components. The versions in this file will match the output of `venctl components kubernetes manifest print-versions` command. 

- Copy file `vars-template.sh` as `vars.sh`. The `Makefile` uses `vars.sh` to load your specific settings.

    > Replace the value for `CYBR_CLOUD_API_KEY` with the value of `apiKey` from your Venafi Control Plane tenant. 
    > Replace the value `CYBR_TEAM_NAME` with the name of the team created in Venafi Control Plane

    
- All commands from terminal will be executed from the `kong-mesh` folder. After you clone the repo change the directory to `projects/kong-mesh` 

- You have created the the required configurations and policies for Firefly to operate in cluster. This is a one time configuration that can be used across all your clusters. Refer to the section [Configuring CyberArk Workload Identity Manager](#configuring-venafi-firefly) to get started. 


# The following section is applicable to Security team only. The steps will walk through configuring CyberArk Workload Identity Manager in Venafi Certificate Manager. If you are a platform engineer skip this section.

## Configuring CyberArk Workload Identity Manager 
Login into [CyberArk Certificate Manager](https://ui.venafi.cloud) If you don't have an account you can sign up for a 30 day trial.

### Creating a Team
If you haven't already created a team and assiged members to it. 
- Go to Settings / Teams
- Click New and provide a name and role for the team. For eg, `platform-admin` and Role as `System Administrator`.  Make sure to assign membership. Set the team name in `vars.sh` if you haven't already. The name of the variable is `CYBR_TEAM_NAME`

### Creating a Sub CA Provider 
The first step to getting started with **CyberArk Workload Identity Manager** is to create a subordinate CA provider. Several upstream CA's are supported but for the purposes of setting up this demo environment 
- Click "Policies / Firefly Sub CA Providers" in left panel 
- Click the "New" -> "Venafi Built-In CA" button. 

> **NOTE** 
> Sub CA Provider can be created using the CyberArk APIs as well. [Venafi Developer Central](https://developer.venafi.com/tlsprotectcloud) is a good place to start to understand the various APIs and recipes that can be used. 

In the presented screen provide the details for the subordinate CA. An example is included in the screenshot below. The common name for the CA that will be bootstrapped is set as `firefly-built-in-180.svc.cluster.local` with the key algorithm as `RSA 2048`. Set the rest of the subject information that best suits your needs. The sample uses the Venafi Built-In CA. For producton, it is recommended to use the organization's CA.

![Creating a Sub CA Provider](../../images/firefly-subca-config.png)

Make sure to save and review the Sub CA Provider you create. 

### Create a policy for certificates issued by Workload Identity Manager
As a next step , we will create a policy that will be used by the **CyberArk Workload Identity Manager** issuer for issuing certificates in cluster. CyberArk Workload Identity Manager provides a very comprehensive policy model for governing how certificates are issued for workloads. Read the CyberArk Certificate Manager documentation for various options. 

To create a policy 
- Click "Policies / Firefly Issuance Policies" in left panel 
- Click New and in the presented screen provide the values for the policy. 

All fields are self explanatory. For information about what the "Type" means read the documentation. For e.g Optional means it is optional to provide a value.  Take a look at the sample policy shown below 
- the name of the policy is *firefly-two-day-RSA-certs*
- the validity of all certs issued by **CyberArk Workload Identity Manager** is 2 days 
- the subject enforces that common name / DNS SAN must end with For e.g `.svc.cluster.local`
- the rest of the subject fields are locked to a certain value and the information provided in the CSR will be not used. 
- the key constraint is set to "Required" and the only allowed value is **RSA 2048**
- the issuance parameters are set with specific values that will be set in the issued certificate.

![CyberArk Workload Identity Manager Policy](../../images/fireflyca-policy.png)

Make sure to save and review the policy you create. 

**NOTE** Create two additonal policies similar to above and name them *firefly-ten-day-RSA-certs* and *firefly-hundred-day-RSA-certs* . For the former set the validity to 10 days and for the latter set it to 100 days. 

The idea is to have different policies that cater to different scenarios that *CyberArk Workload Identity Manager* will fulfill. 

**Policy for Kong Mesh**
Create a additonal policy with name `firefly-kong-mesh-policy` and set the client certificate validity to `1 hour`. Accept all defaults for now. You will need to set the key constraint. Set it to `RSA 2048` and the Issuance parameters to `Digital Signature` & `Key Encipherment` . Extended Key Usage to `Server Authentication` & `Client Authentication`  

> When you access "Policies / Firefly Issuance Policies" you should see 4 policies in addition to any other you may have created. 

### Creating a configuration for CyberArk Workload Identity Manager runtime operations
This is the final step in the process of setting up CyberArk Workload Identity Manager for runtime operation. **CyberArk WIM** at runtime is associated with a configuration that holds one or more policies. We have created three policies. Each of the policy will cater to different types of workloads associated with a single configuration. 

For e.g the policy created to issue certs with validity of 2 days is likely for highly ephemeral workloads. The 10 day and the 100 day certs may be applicable to different types of workloads.  

To create a configuration,
- Click "Configurations / Firefly Configurations" in the left panel 
- Click New and in the presented screen provide a name and the required fields. 

The required fields on the screen are self explanatory. For addtional details, read the documentation. Sample screenshot available below as well. 
- set the name of the config to `my-firefly-config`
- the selected Sub CA Provider is what we created as a Sub CA Provider. In this example it is `firefly-provider-with-built-in-ca`
- the associated policies are the policy we created earlier. You should associate three policies as shown in the screenshot below. 
- Leave the service account empty for now. You can create a service account manually from "Settings / Service Accounts" if you prefer. In this demo we will be creating it from the CLI and then associate the service account before installing Firefly runtime. 
- Choose None for Client Authentication and Authorization Type. We won't be needing it for this demo. 


![CyberArk Workload Identity Manager Configuration](../../images/fireflyca-config.png)

Make sure to save and review the configuration you create. 

# The following section is applicable to Platform team only. The steps will walk through installation of Venafi components in cluster. 

**NOTE**
> Make sure your `vars.sh` is setup as documented in the Pre-requisites section.

## Installing Venafi components in cluster

The `Makefile` has several targets and we will walk through all of them to install and configure the Venafi components as listed in the [documentation](!https://docs.venafi.cloud/vaas/k8s-components/c-tlspk-enterprise-components/)

All components will be installed using `venctl` which is a Venafi Kubernetes Manifest utility. More details can be found [here](https://docs.venafi.cloud/vaas/k8s-components/c-vmg-overview/)


### Preparing the cluster to run Venafi components

### STEP 1
Instructions assume that you are running everything from the directory `kubernetes-demos/projects/kong-mesh` directory

Run 
```
make init-cloud 
```
Running `init-cloud` will 
- create a directory called `artifacts` and all the necessary files required to deploy **CyberArk components in cluster** will be generated here. 
- create a namespace in your cluster called `sandbox` for sample certs.
- create a secret for Firefly to connect to CyberArk Certificate Manager in the namespace where cert-manager is already deployed

The output running `make init-cloud` will look as below. 
```
❯ make init-cloud
namespace/sandbox created
Credentials for venafi registry
secret/venafi-image-pull-secret created
Credentials for Firefly
secret/venafi-credentials created
```

### STEP 2

**NOTE** 
> In the previous step a service account was created. This service account needs to be associated with the Firefly configuration in the UI. If you do not have access to the Venafi UI, ask the security team to associate the service account to the Venafi Firefly configuration. 

The Venafi Kubernetes Manifest Generator is a handy tool (a helmfile wrapper) that can be used for generating the required manifests. The target to generate the required manifests is `make generate-venafi-manifests`. There is detailed documentation covering a lot of details about how the manifest generator works [here](!https://docs.venafi.cloud/vaas/k8s-components/c-vmg-overview/) The CLI `venctl` is also has detailed help. 

Review the target `generate-venafi-manifests` and you will see what it is trying to do . It reads the required versions to install from `versions.sh`. You can choose which components to install based on the usecases that are relevant to you. In this demo we are installing most of the components. 

Run
```
make generate-venafi-manifests
```
You will see an output that simply says 
`Generating Venafi Helm manifests for installation` 

Review the contents if you want to. The generated file is `artifacts/venafi-install/venafi-manifests.yaml` 

### STEP 3

In this step we will be installing all the Venafi components by simply running the target `install`. 
Run 
```
make install
```


Once complete, you should see the following that confirms the installation

```
UPDATED RELEASES:
NAME                NAMESPACE   CHART                             VERSION   DURATION
venafi-connection   cyberark    venafi-charts/venafi-connection   v0.4.0          2s
cert-manager        cyberark    venafi-charts/cert-manager        v1.17.1        35s
firefly             cyberark    venafi-firefly/firefly            v1.6.0         18s
```

By simply adding additional kubernetes contexts, you can install the same configuration on addtional clusters. 

### STEP 4

Let's create a few sample certificates. As firefly is installed in the cluster, just using the firefly group is sufficient for requesting certificates. There is no need to create a cert-manager `Issuer`. Review the sample certificate `yaml` at [samples/sample-firefly-certificates.yaml](samples/sample-firefly-certificates.yaml) and you will notice a specific annotation that ensure `CertificateRequest` is fulfilled. 

Run 
```
make create-firefly-sample-certs
```
to create `Certificates`

The output you see will be 

```
certificate.cert-manager.io/kong-mesh-2d-1.svc.cluster.local created
certificate.cert-manager.io/kong-mesh-10d-1.svc.cluster.local created
certificate.cert-manager.io/kong-mesh-100d-1.svc.cluster.local created
certificate.cert-manager.io/kong-mesh-test01.svc.cluster.local created
```
Run `kubectl get CertificateRequest -n sandbox` to see the certificate requests that were generated and fulfilled. You should see 

```
NAMESPACE   NAME                                   APPROVED   DENIED   READY   ISSUER         REQUESTER                                     AGE
sandbox     kong-mesh-100d-1.svc.cluster.local-1   True                True    firefly-kong   system:serviceaccount:cyberark:cert-manager   3s
sandbox     kong-mesh-10d-1.svc.cluster.local-1    True                True    firefly-kong   system:serviceaccount:cyberark:cert-manager   3s
sandbox     kong-mesh-2d-1.svc.cluster.local-1     True                True    firefly-kong   system:serviceaccount:cyberark:cert-manager   2s
sandbox     kong-mesh-test01.svc.cluster.local-1   True                True    firefly-kong   system:serviceaccount:cyberark:cert-manager   3s
```
**NOTE** All certificate requests are automatically approved as we installed cert-manager with it's `default-approver`. If default-approver wasn't enabled you are required to create a `CertificateRequestPolicy` to approve certificate requests. 

### STEP 5

As you noted above, every `CertificateRequest` resource that is generated by firefly requires a specific annotation that will be used for validation. Eventually when we install kong-mesh and have kong automatically generate certificate requests, we need a way to make sure these annotations exist. To do this automatically, we will use kyverno. In this step, we will install kyverno and then create a `ClusterPolicy`. 

To install kyverno, simply run 

```
make install-kyverno
```
Once the installation is complete run `make wait-for-kyverno` to see

```
pod/kyverno-admission-controller-6468f4bbd4-p62c2 condition met
pod/kyverno-background-controller-86d48fc7db-2k5fr condition met
pod/kyverno-cleanup-controller-7766d9df55-c7j9c condition met
pod/kyverno-reports-controller-8c4667558-4d89m condition met
```
This tells kyverno is installed and ready. 


### STEP 6
Create a `ClusterPolicy` to automatically inject an annotation to `CertificateRequest` resource.   

Review the file [templates/kyverno/cluster-policy.yaml](templates/kyverno.cluster-policy.yaml) 

**IMPORTANT** The `policy-name` annotation drives what policy is used for fullfilling the certificate request. The teams requesting certificates just need to know the name of the policy and the required properties to send in the certificate. Many of the certificate properties have been locked by the administrator and/or set as defaults.  The `firefly.venafi.com/policy-name` annotation is automatically injected into every certificate request resource. The name of the policy used is `firely-kong-mesh-policy`. If the name of the policy differs in your setup, use that name. 

Run 
```
make create-kyverno-policy
```

This will create a `ClusterPolicy` resource. Review the resource simply by running `kubectl get ClusterPolicy -A` to see that it's ready. 

### STEP 7
Install Kong Mesh by running

```
make install-kong-mesh
```
In additon to other output on the screen you will see
```
Update Complete. ⎈Happy Helming!⎈
NAME: kong-mesh
LAST DEPLOYED: Mon May 12 08:50:26 2025
NAMESPACE: kong-mesh-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
kong-mesh has been installed!

Your release is named 'kong-mesh'.
```

Check if Kong Mesh is up by running `make wait-for-kong-mesh` to see

```
pod/kong-mesh-control-plane-87b6f7bd5-hllpn condition met
```

### STEP 8
Setup Traffic Permissions. Before we deploy an application we need to do a couple of things. In this step we will create a `MeshTrafficPermission`. 
Review the MTP [templates/kong/mesh-traffic-permission.yaml](templates/kong.mesh-traffic-permission.yaml) 

Run,
```
make setup-traffic-permissons
```
to see `meshtrafficpermission.kuma.io/mtp created`

### STEP 9
Review the `Mesh` config. This is where we tell Kong Mesh to use **Firefly** to sign all mesh workloads. The `Mesh` config is located at [templates/kong/mesh.yaml](templates/kong.mesh.yaml)

Connect Kong Mesh and Firefly by running,

```
 make configure-kong-with-firefly
```

To look at the configuration run `kubectl describe Mesh` and you will see
```
Spec:
  Mtls:
    Backends:
      Conf:
        Issuer Ref:
          Group:  firefly.venafi.com
          Kind:   Issuer
          Name:   firefly-kong
      Dp Cert:
        Rotation:
          Expiration:  1h
      Name:            certmanager-1
      Type:            certmanager
    Enabled Backend:   certmanager-1
Events:                <none>
```
Note that Kong data plane certificate expiration is set to 1h and the backend is enabled to use cert-manager. This will ensure all certificates are issued by a cert-managed backed Issuer.

### STEP 10
Install sample app. The sample appplication will be created in `kuma-demo` namespace. 
Run 
```
make create-sample-app wait-for-sample-app
```
to see

```
namespace/kuma-demo created
deployment.apps/redis created
service/redis created
deployment.apps/demo-app created
service/demo-app created
pod/demo-app-56c84465fd-ssqj7 condition met
```

### STEP 11
Before we inspect the certificates used by Kuma, let's make sure that the we can access the sample app and also make sure that the control plane API's are available. 
To start the sample app, simply run 
```
kubectl port-forward svc/demo-app -n kuma-demo 5000:5000
```
Access `localhost:5000` and validate that clicking on Increment increments the counter. 

To make the control plane API's available, run 

```
kubectl port-forward svc/kong-mesh-control-plane -n kong-mesh-system 5681:5681
```
You can optionally access the Kong Control Plane GUI using `localhost:5681/gui`

### STEP 12
To inspect the certificate issued by Kong Mesh with Firefly run
```
make print-kong-svid
```
Review the target. This target requires you to have `kumactl` installed. 

The output will look as 

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            13:fg:15:25:ae:d0:86:5f:fd:2a:19:gf:89:12:62:9r
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=US, ST=MA, L=Newton, O=CyberArk Inc, OU=Firefly Unit, CN=firefly-1-20250512084812 firefly-built-in-180.svc.cluster.local
        Validity
            Not Before: May 12 15:28:48 2025 GMT
            Not After : May 12 16:28:48 2025 GMT
        Subject: 
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:aa:7a:36:c5:0b:8c:97:67:2a:cf:69:cc:e2:4a:
                    33:1b
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 ........
                ......
            ........
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Subject Alternative Name: critical
                URI:spiffe://default/demo-app_kuma-demo_svc_5000, URI:kuma://app/demo-app, URI:kuma://k8s.kuma.io/namespace/kuma-demo, URI:kuma://k8s.kuma.io/service-name/demo-app, URI:kuma://k8s.kuma.io/service-port/5000, URI:kuma://kubernetes.io/hostname/mis-demo-cluster-3008391205-control-plane, URI:kuma://kuma.io/protocol/http, URI:kuma://kuma.io/service/demo-app_kuma-demo_svc_5000, URI:kuma://kuma.io/zone/default, URI:kuma://pod-template-hash/56c84465fd
    Signature Algorithm: sha256WithRSAEncryption
```

Note that the duration of the certificate is `1 hour` and the issuer is **Firefly** 


## Access the CyberArk Certificate Manager to view the Issuer Certificates and the associated metrics

Access the UI,
- Click "Inventory / Firefly Issuer Certificates" in from the left panel

All the Issuer certificates and the metrics will be presented for the security team to monitor and review as shown below 

![Certs issued by Firefly](../../images/firefly-certs-issued.png)
