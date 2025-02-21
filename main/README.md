# TLS Protect for Kuberentes & Firefly 

## Requirements  
- You have access to the [Venafi Control Plane](!https://ui.venafi.cloud) and have the entitlements to use 
   - TLS Protect Cloud
   - TLS Protect for Kubernetes
   - Firefly 

## Pre-requisites 
Before you start, there are some requirements to setup the environment.
The demos use a `Makefile` for all operations. Always review the target you are asked to execute. If you prefer to adapt it to another tool, please do. 

- Install the command line tool that we will be using for installing and configuring Venafi components in cluster. You can run `make install-venctl` to do this. Running this comamnd again, will attempt an upgrade if one is available. `venctl` is frequently updated with new capabilities so use `make install-venctl` frequently. 

- Review the file `versions.sh`. You don't need to change it unless you want to pin a component to a specific version. This repo will likely be pinned to latest versions of all the components. The versions in this file will match the output of `venctl components kubernetes manifest print-versions` command. 

- Copy file `vars-template.sh` as `vars.sh`. The `Makefile` uses `vars.sh` to load your specific settings.

    > Replace the value for `CYBR_CLOUD_API_KEY` with the value of `apiKey` from your Venafi Control Plane tenant. 

    > Replace the value for `CYBR_ZONE_PRIVATE_CA` with the value of the issuing template path. If you don't know what this is, login to Venafi Control Plane, create a issuing template with Venafi BuiltIn CA and create an application. The ZONE is of the form application/issuing-template. Refer to Venafi Control Plane documention for details about how to create an application , assign ownership, etc. 

    > No other variables are required to be setup at this time. We will revisit the other variables as needed. 

- Optionally copy `cloud-settings-template.sh` as `cloud-settings.sh`. This file is optionally included in the `Makefile` and you can use only if you want to automate things in Google Cloud
- All commands from terminal will be executed from the `main` folder. After you clone the repo change the directory to `main` 

- You have created the required configurations and policies for Firefly to operate in cluster. This is a one time configuration that can be used across all your clusters. Refer to the section [Configuring Venafi Firefly](#configuring-venafi-firefly) to get started. 



## Configuring Venafi Firefly 
Login into [Venafi TLS Protect Cloud](https://ui.venafi.cloud) If you don't have an account you can sign up for a 30 day trial.

### Creating a Team
If you haven't already created a team and assigned members to it. 
- Go to Settings / Teams
- Click New and provide a name and role for the team. For eg, `platform-admin` and Role as `System Administrator`.  Make sure to assign membership. Set the team name in `vars.sh`. The name of the variable is `CYBR_TEAM_NAME`

### Creating a Sub CA Provider 
The first step to getting started with **Firefly** is to create a subordinate CA provider. Several upstream CA's are supported but for the purposes of setting up this demo environment 
- Click "Policies / Firefly Sub CA Providers" in left panel 
- Click the "New" -> "Venafi Built-In CA" button. 

> **NOTE** 
> Sub CA Provider can be created using the Venafi APIs as well. [Venafi Developer Central](https://developer.venafi.com) is a good place to start to understand the various APIs and recipes that can be used. 

In the presented screen provide the details for the subordinate CA. An example is included in the screenshot below. The common name for the CA that will be bootstrapped is set as `firefly-built-in-180.svc.cluster.local` with the key algorithm as `RSA 2048`. Set the rest of the subject information that best suits your needs. The sample uses the Venafi Built-In CA. For producton, it is recommended to use the organization's CA.

![Creating a Sub CA Provider](../images/firefly-subca-config.png)

Make sure to save and review the Sub CA Provider you create. 

### Create a policy for certificates issued by Firefly
As a next step , we will create a policy that will be used by the **Firefly** issuer for issuing certificates in cluster. Venafi Firefly provides a very comprehensive policy model for governing how certificates are issued for workloads. Read the TLS Protect Cloud documentation for various options. 

To create a policy 
- Click "Policies / Firefly Issuance Policies" in left panel 
- Click New and in the presented screen provide the values for the policy. 

All fields are self explanatory. For information about what the "Type" means read the documentation. For e.g Optional means it is optional to provide a value.  Take a look at the sample policy shown below 
- the name of the policy is *firefly-two-day-RSA-certs*
- the validity of all certs issued by **Firefly** is 2 days 
- the subject enforces that common name / DNS SAN must end with For e.g `.svc.cluster.local`
- the rest of the subject fields are locked to a certain value and the information provided in the CSR will be not used. 
- the key constraint is set to "Required" and the only allowed value is **RSA 2048**
- the issuance parameters are set with specific values that will be set in the issued certificate.

![Firefly Policy](../images/fireflyca-policy.png)

Make sure to save and review the policy you create. 

**NOTE** Create two additonal policies similar to above and name them *firefly-ten-day-RSA-certs* and *firefly-hundred-day-RSA-certs* . For the former set the validity to 10 days and for the latter set it to 100 days. 

The idea is to have different policies that cater to different scenarios that *Firefly* will fulfill. 

### Creating a policy for Service mesh usecase

In addition to the above 3 policies, let's create a fourth policy but with slightly different characteristics. This is for signing service mesh worklods using Firefly. 
Similar to how we created a policy before create a new policy called `firefly-istio-service-mesh-policy` You can name it whatever you need it to be. See below for the properties that needs to be set for the policy and also a screenshot.

| Property          | Type |
| :---              |    :----:   | 
| Validity   | 1 Hour        | 
| Commmon Name      | `istiod.istio-system.svc`<br>`^.*`       |
| DNS(SAN)   | `istio-csr.cyberark.svc`<br>`cert-manager-istio-csr.cyberark.svc`<br>`istiod.istio-system.svc`        | 
| URI Addresss (SAN)   | `^spiffe://cluster\.local/ns/.*/sa/.*`        | 
| Key Constraint   | RSA 2048        | 
| Key Usage   | Key Encipherment <br> Digital Signature        | 
| Extended Key Usage   | Server Authentication <br> Client Authentication        | 

![Policy for Istio](../images/firefly-istio-policy.png)


> When you access "Policies / Firefly Issuance Policies" you should see 4 policies in addition to any other you may have created. 


### Creating a configuration for Firefly runtime operations
This is the final step in the process of setting up Firefly for runtime operation. **Firefly** at runtime is associated with a configuration that holds one or more policies. We have created three policies. Each of the policy will cater to different types of workloads associated with a single configuration. 

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


![Firefly Configuration](../images/fireflyca-config.png)

Make sure to save and review the configuration you create. 


## Installing Venafi components in cluster

The `Makefile` has several targets and we will walk through all of them to install and configure the Venafi components as listed in the [documentation](!https://docs.venafi.cloud/vaas/k8s-components/c-tlspk-enterprise-components/)

All components will be installed using `venctl` which is a Venafi Kubernetes Manifest utility. More details can be found [here](https://docs.venafi.cloud/vaas/k8s-components/c-vmg-overview/)


### Preparing the cluster to run Venafi components

### STEP 1
Instructions assume that you are running everything from the directory `kubernetes-demos/main` directory

Run 
```
make init-cloud 
```
Running `init-cloud` will 
- create a directory called `artifacts` and all the necessary files required to deploy **Venafi** will be generated here. 
- create two namespaces in your cluster `sandbox` and `venafi` 
- create 3 service accounts that start with name `demo-`. These service accounts can be found in the UI under `Settings / Service Accounts`. Each service account is for a specific purpose and is obvious when you review them in the Venafi Control Plane. 

```
❯ make init-cloud
Service account for certificate discovery
Creating a new service account for the Venafi Kubernetes Agent
 ✅    Running prerequisite checks
Service Account id=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Service account was created successfully file=artifacts/cyberark-install/cybr_mis_agent_secret.json format=secret
Creating Service Account in Venafi Control Plane for registry secret
Creating a new service account for Venafi OCI registry
 ✅    Running prerequisite checks
Service Account id=YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
Service account was created successfully file=artifacts/cyberark-install/cybr_mis_registry_secret.json format=secret scopes="[cert-manager-components enterprise-approver-policy enterprise-venafi-issuer]"
Creating Service account in Venafi Control Plane for Firefly
Creating a new service account for the Venafi Firefly
 ✅    Running prerequisite checks
Service Account id=ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
Service account was created successfully file=artifacts/cyberark-install/cybr_mis_firefly_secret.json format=secret
namespace/cyberark created
namespace/sandbox created
Credentials for venafi registry
secret/venafi-image-pull-secret created
Credentials for certificate discovery
secret/agent-credentials created
Credentials for Venafi Firefly
Credentials for Firefly
secret/venafi-credentials created
```

**NOTE** There is a separate target called `init-dc` that can be used for Venafi TLS Protect Datacenter. You will need to first set the `vars.sh` with the required values.  

### STEP 2

The Venafi Kubernetes Manifest Generator is a handy tool (a helmfile wrapper) that can be used for generating the required manifests. The target to generate the required manifests is `make generate-venafi-manifests`. There is detailed documentation covering a lot of details about how the manifest generator works [here](!https://docs.venafi.cloud/vaas/k8s-components/c-vmg-overview/) The CLI `venctl` is also has detailed help. 

Review the target `generate-venafi-manifests` and you will see what it is trying to do . It reads the required versions to install from `versions.sh`. You can choose which components to install based on the usecases that are relevant to you. In this demo we are installing most of the components. 

Run
```
make generate-venafi-manifests
```
You will see an output that simply says 
`Generating Venafi Helm manifests for installation` 

Review the contents if you want to. The generated file is `artifacts/cyberark-install/venafi-manifests.yaml` 

### STEP 3

In this step we will be installing all the Venafi components by simply running the target `install`. One thing to remember before you run install is to associate the service account for the **Firefly** configuration. 
The name of the generated service account is `demo-firefly-<random-number>` 

Go to `Configurations / Firefly Configurations` in the UI and 
- click on the configuration
- click on Service Accounts dropdown and choose `demo-firefly-<random-number>` 
- Save the configuration

Run 
```
make install
```
This command asks for a verbal confirmation asking you if you have associated the service account to **Firefly** configuration. Type `y` to proceed

```
❯ make install
Have you attached the Firefly service account to your config in the UI? [y/N]
```
Typing `y` will start the install process and will take about 2-3 minutes to complete 

Once complete, you should see the following that confirms the installation

```
UPDATED RELEASES:
NAME                             NAMESPACE   CHART                                          VERSION   DURATION
venafi-connection                cyberark    venafi-charts/venafi-connection                v0.3.1          2s
cert-manager                     cyberark    venafi-charts/cert-manager                     v1.16.3        23s
cert-manager-csi-driver          cyberark    venafi-charts/cert-manager-csi-driver          v0.10.2         0s
venafi-enhanced-issuer           cyberark    venafi-charts/venafi-enhanced-issuer           v0.15.0        23s
cert-manager-csi-driver-spiffe   cyberark    venafi-charts/cert-manager-csi-driver-spiffe   v0.8.2         29s
approver-policy-enterprise       cyberark    venafi-charts/approver-policy-enterprise       v0.20.0        33s
venafi-kubernetes-agent          cyberark    venafi-charts/venafi-kubernetes-agent          1.4.0          39s
firefly                          cyberark    venafi-firefly/firefly                         v1.5.0         10s
trust-manager                    cyberark    venafi-charts/trust-manager                    v0.15.0        27s
```

All of the above components are installed and running in the `cyberark` namespace in your cluster. `make install` uses `venctl` to install the components. By simply adding additional kubernetes contexts, you can install the same configuration on addtional clusters. 

### STEP 4

All certificate requests will denied by default unless there is a policy that automatically approves the certificate requests. Before we create any certificates we need to create some policies. 
Run 
```
make create-certificate-policy
```
to create a `CertificateRequestPolicy`

The output you see will be 

```
certificaterequestpolicy.policy.cert-manager.io/cert-policy-for-venafi-certs created
certificaterequestpolicy.policy.cert-manager.io/cert-policy-for-venafi-firefly-certs created
clusterrole.rbac.authorization.k8s.io/venafi-issuer-cluster-role created
clusterrolebinding.rbac.authorization.k8s.io/venafi-issuer-cluster-role-binding created
```
Run `kubectl get crp` to see the policies. The associated role and rolebinding defines who is allowed. Describe or review policy available at [templates/common/cert-policy-and-rbac.yaml](templates/common/cert-policy-and-rbac.yaml) 

### STEP 5

Creating an issuer. We will now create an issuer using the `ZONE` defined in `vars.sh`. To create an issuer simply run,

```
make create-venafi-cloud-privateca-cluster-issuer 
```
This will create a few new resources. A `VenafiConnection` resource and a `VenafiClusterIssuer` resource. The `VenafiConnection` resource will be in the `cyberark` namespace and the cluster issuer is as the name suggests, cluster-scoped.
The output you see will be 

```
clusterrole.rbac.authorization.k8s.io/read-creds-secret-role-for-venafi-connection created
clusterrolebinding.rbac.authorization.k8s.io/read-creds-secret-role-for-venafi-connection created
secret/venafi-cloud-credentials created
venaficonnection.jetstack.io/venafi-connection created
venaficlusterissuer.jetstack.io/venafi-privateca-cluster-issuer created
```

Run 
```
kubectl get VenafiClusterIssuer
```
and you should see 
```
NAME                              READY   REASON    MESSAGE                         LASTTRANSITION   OBSERVEDGENERATION   GENERATION   AGE
venafi-privateca-cluster-issuer   True    Checked   Succeeded checking the issuer   47s              1                    1            48s
```

### STEP 6
Let's validate that **Firefly** can issue certificates 

Review the file [samples/sample-firefly-certificates.yaml](samples/sample-firefly-certificates.yaml) 

**IMPORTANT** The `policy-name` annotation drives what policy is used for fullfilling the certificate request. The teams requesting certificates just need to know the name of the policy and the required properties to send in the certificate. Many of the certificate properties have been locked by the administrator and/or set as defaults.  The `firefly.venafi.com/policy-name` annotation for each of the three certificates is set to the a different policy.

Run 
```
make create-sample-firefly-certs
```

This will create the certificates in the `sandbox` namespace and can be validated by running,

```
kubectl get Certificate -n sandbox
```
The output will be 

```
NAME                                    READY   SECRET                                  AGE
cert-hundred-days-1.svc.cluster.local   True    cert-hundred-days-1.svc.cluster.local   3m
cert-ten-days-1.svc.cluster.local       True    cert-ten-days-1.svc.cluster.local       3m
cert-two-days-1.svc.cluster.local       True    cert-two-days-1.svc.cluster.local       3m
```

Optionally, look at the associated `CertificateRequest` and `Secret` resources. 
To look at `CertificateRequest` resources run 

```
kubectl get CertificateRequests -n sandbox 
```
The output will be

```
NAME                                      APPROVED   DENIED   READY   ISSUER    REQUESTER                                     AGE
cert-hundred-days-1.svc.cluster.local-1   True                True    firefly   system:serviceaccount:cyberark:cert-manager   25s
cert-ten-days-1.svc.cluster.local-1       True                True    firefly   system:serviceaccount:cyberark:cert-manager   25s
cert-two-days-1.svc.cluster.local-1       True                True    firefly   system:serviceaccount:cyberark:cert-manager   25s
```
Note that the issuer is set to **firefly**

To confirm the validity of each of the certificate optionally run 

Run the following , 
```
kubectl get secret cert-two-days-1.svc.cluster.local -n sandbox -o jsonpath="{.data.tls\.crt}" | base64 -d | openssl x509 -text | grep  CN=cert-two-days-1.svc.cluster.local -B4
```
to see

```
        Issuer: C=US, ST=TX, L=Frisco, O=CyberArk Inc, OU=Firefly Unit, CN=firefly-1-20250208113912 firefly-built-in-180.svc.cluster.local
        Validity
            Not Before: Feb  8 17:42:03 2025 GMT
            Not After : Feb 10 17:42:03 2025 GMT
        Subject: C=USA, ST=MA, L=Newton, O=CyberArk Inc, OU=Firefly Unit 3, CN=cert-two-days-1.svc.cluster.local
```

Run the following, 
```
kubectl get secret cert-ten-days-1.svc.cluster.local -n sandbox -o jsonpath="{.data.tls\.crt}" | base64 -d | openssl x509 -text | grep  CN=cert-ten-days-1.svc.cluster.local -B4
```

to see 
```
        Issuer: C=US, ST=TX, L=Frisco, O=CyberArk Inc, OU=Firefly Unit, CN=firefly-1-20250208113912 firefly-built-in-180.svc.cluster.local
        Validity
            Not Before: Feb  8 17:42:03 2025 GMT
            Not After : Feb 18 17:42:03 2025 GMT
        Subject: C=USA, ST=MA, L=Newton, O=CyberArk Inc, OU=Firefly Unit 2, CN=cert-ten-days-1.svc.cluster.local
```

Run the following
```
kubectl get secret cert-hundred-days-1.svc.cluster.local -n sandbox -o jsonpath="{.data.tls\.crt}" | base64 -d | openssl x509 -text | grep  CN=cert-hundred-days-1.svc.cluster.local -B4
```
to see
```
        Issuer: C=US, ST=TX, L=Frisco, O=CyberArk Inc, OU=Firefly Unit, CN=firefly-1-20250208113912 firefly-built-in-180.svc.cluster.local
        Validity
            Not Before: Feb  8 17:42:03 2025 GMT
            Not After : May 19 17:42:03 2025 GMT
        Subject: C=USA, ST=MA, L=Newton, O=CyberArk Inc, OU=Firefly Unit 1, CN=cert-hundred-days-1.svc.cluster.local
```

## Access the Venafi Control Plane to view the Issuer Certificates and the associated metrics

Access the UI,
- Click "Inventory / Firefly Issuer Certificates" in from the left panel

All the Issuer certificates and the metrics will be presented for the security team to monitor and review as shown below 

![Certs issued by Firefly](../images/firefly-certs-issued.png)

### STEP 7

Let's create some addtional certificates in cluster and deploy a few pods to use those certificates. To seed some addtional data simply run

`make seed-data` 

This will create a few secrets, few certificates and a few pods in the `sandbox` namespace.  The output on the screen will display the information. 

If you are operating in a cluster where you may already have a certificates, you don't need to seed any sample data. The purpose of this step is to demonstrate the Venafi discovery capabilities. 
One of the service accounts that we created during the initial step was to setup the discovery of certificates from clusters. 
After about couple of minutes or so login to the UI and access "Installations / Kubernetes Clusters".
You should see a cluster registered as `mis-demo-cluster-<random number>` 

Click on the cluster name and then click `View Certificates`. Pick one of the certificates, For eg. `cipher-snake.svc.cluster.local` and click on it. Review the details. You will notice that the Key size is likely non-compliant. Review the `Installations` by clicking on it. Expand the cluster resources to find that this certificate is actually in use in a workload and it's lifecycle is not managed at all. 

Addtional exercise: Optionally, you can have TLS Protect Datacenter pull this discovered data into a policy folder as well.  


# Configure Firefly to sign Istio mesh workloads

Now that we have validated Firefly and have issued a few certificates let us extend our Firefly setup to sign all incoming Istio mesh workloads. In this section we will be installing a few additional components in the cluster. 

## Setting up Istio and the required components

As always, review each target before you run to understand what exactly will be executed. 

### STEP 1

We will create a couple of namespaces `istio-system` and `mesh-apps`. Review `namespaces/mesh-apps.yaml` and you will notice that we have a label `istio-injection: enabled` to ensure all workloads are mesh enabled. 

Additionally, review [templates/helm/istio-csr-values.yaml](templates/helm/istio-csr-values.yaml) This is the chart that configures how Venafi cert-manager istio-csr is installed and configured. 
- You will note that there is a specific annotation that tells istio-csr what policy to use for signing all mesh workloads. In this demo, the policy used is `firefly-istio-service-mesh-policy`
- You wil notice a reference to `firefly-mesh-wi-issuer`. This is the issuer that will be used for signing all incoming mesh workloads. 

Run
```
make mesh-step1
```

This will create two namespaces and and a *Firefly* issuer. You should see the below output 
```
namespace/istio-system created
namespace/mesh-apps created
issuer.firefly.venafi.com/firefly-mesh-wi-issuer created
```

### STEP 2
istio-csr requires a trust anchor that needs to be mounted when installed. The reference to `root-cert.pem` in [templates/helm/istio-csr-values.yaml](templates/helm/istio-csr-values.yaml) is for the trust anchor. 

Before you run the target for `step2` review the target `make-step2`. This target calls another target called `_create_sourceCA`. The variable `CYBR_TRUST_ANCHOR_ROOT_CA_PEM` should be set in the `vars.sh`. The value will be a path to a PEM file that acts as the trust anchor. The referred PEM file does not exist in the repo. You will need to create the PEM file. You can populate the contents of this file by accessing Venafi Control Plane and downloading the CA. For this demo it will be the root of venafi built in CA. 

Run 
```
make mesh-step2
```

Running the target produces the below output. A trust-manager managed `Bundle` called `istio-ca-root-cert` is created that is automatically managed. `istio-csr` uses the `Bundle` and will make it automatically available when `secret/cyberark-trust-anchor` changes.  
```
❯ make mesh-step2
secret/cyberark-trust-anchor created
Creating Firefly trust anchor
configmap/istio-csr-ca created
bundle.trust.cert-manager.io/istio-ca-root-cert created
```
Review the `Bundle` by simply running, 

```
kubectl describe Bundle istio-ca-root-cert -n istio-system 
```
and you will see 

```
...
...
Events:
  Type    Reason  Age   From     Message
  ----    ------  ----  ----     -------
  Normal  Synced  29s   bundles  Successfully synced Bundle to namespaces that match this label selector: issuer=cyberark-firefly
```

### STEP 3
With all the pre-requisites for istio-csr taken care of, we will now install it using venctl. Review `mesh-step3` and you will find that it generates venafi manifests and then installs istio-csr
Run 
```
make mesh-step3
```
and you will see the following output in the end. There will be more on the screen showing progress. cert-manager is also listed as it's the minimum required dependency. In this demo we use many of the enterprise capabilities that are already installed. 
```
❯ make mesh-step3
Generating Venafi Helm manifests for installing istio-csr
.........
........
UPDATED RELEASES:
NAME                     NAMESPACE   CHART                                  VERSION   DURATION
cert-manager             cyberark    venafi-charts/cert-manager             v1.16.3         2s
cert-manager-istio-csr   cyberark    venafi-charts/cert-manager-istio-csr   v0.14.0        14s
```

Validate that all the components are running using
```
kubectl get pods -n cyberark
```
and you should see 

```
NAME                                                      READY   STATUS    RESTARTS        AGE
cert-manager-7b5fbf4c8c-xtq6p                             1/1     Running   0               10m
cert-manager-approver-policy-86c9f87b69-lds9m             1/1     Running   0               10m
cert-manager-cainjector-7bdb4b49fb-nzsq2                  1/1     Running   0               10m
cert-manager-csi-driver-9wrcz                             3/3     Running   1 (9m28s ago)   10m
cert-manager-csi-driver-spiffe-approver-7b5df6bb7-8g4tk   1/1     Running   0               10m
cert-manager-csi-driver-spiffe-driver-wgfhj               3/3     Running   0               10m
cert-manager-istio-csr-67555f88f-x79xx                    1/1     Running   0               69s
cert-manager-webhook-67cbd84cc9-sr5rl                     1/1     Running   0               10m
firefly-54c68867c9-4d266                                  1/1     Running   0               9m24s
firefly-54c68867c9-vjfkz                                  1/1     Running   0               9m24s
trust-manager-ffc4dd9f8-7zpv9                             1/1     Running   0               9m23s
venafi-enhanced-issuer-69c56f45f-m55pz                    1/1     Running   0               10m
venafi-enhanced-issuer-69c56f45f-wgjc5                    1/1     Running   0               10m
venafi-kubernetes-agent-f874f6774-hr7tx                   1/1     Running   0               10m
```

The `istio-csr` installation automatically creates a new certificate called `istiod-dynamic`  that will be bootstrapped to Istio for signing all mesh workloads

Review the certificate issued by Fireflyfor Istio by running
```
kubectl get certificate istiod-dynamic -n istio-system
```
You can additonally inspect the secret bootstrapped to Istio by running 
```
 kubectl get secret istiod-tls -n istio-system -o jsonpath="{.data.tls\.crt}" | base64 -d | openssl x509 -text | grep Issuer -A4
```
and you should see 
```
        Issuer: C=US, ST=TX, L=Frisco, O=CyberArk Inc, OU=Firefly Unit, CN=firefly-1-20250208113912 firefly-built-in-180.svc.cluster.local
        Validity
            Not Before: Feb  8 17:47:31 2025 GMT
            Not After : Feb  8 18:47:31 2025 GMT
        Subject: CN=istiod.istio-system.svc
```
This is the `istiod` secret that Istio will use for signing all incoming mesh workloads. 

### STEP 4

We will now install Istio by running the following. Istio is installed using the `IstioOperator` . The file is located at [templates/servicemesh/istio-config.yaml](templates/servicemesh/istio-config.yaml) for review. Note the `caAddress` and the setting for `CA_SERVER`. The `caAddress` points to `istio-csr` service and the built in `CA_SERVER` is turned off. The `caAddress` needs to be correctly pointing for Istio to work with `istio-csr`

Run 
```
make mesh-step4 
```
and you should see the following. At the time of writing, the version of istio installed is `1.24.2`
```
❯ make mesh-step4
✔ Istio core installed ⛵️                                                                                                                                             
✔ Istiod installed 🧠                                                                                                                                                 
✔ Egress gateways installed 🛫                                                                                                                                        
✔ Ingress gateways installed 🛬                                                                                                                                       
✔ Installation complete   
```

**Optional**
Optionally, add istio addons Kiali, Grafana and Prometheus to your installation. Run

```
make mesh-addons
```
and you should see kiali , prometheus and grafana installed in the `istio-system` namespace. You can access kiali by running `istioctl dashboard kiali` to look at the traffic, the workload identities , etc. 

### STEP 5
In this step we will create a `PeerAuthentication` to ensure all workloads communicate to each other STRICTLY using mTLS. 

Run
```
make mesh-step5
```
You will see 
```
peerauthentication.security.istio.io/global created
```
Let's inspect the `PeerAuthentication` resource by running 
```
kubectl get PeerAuthentication -n istio-system
```
to see that mTLS mode is set to STRICT
```
NAME     MODE     AGE
global   STRICT   55s
```

### STEP 6
With all the components installed in cluster and istio configured to use Firefly issued certificate for signing mesh workloads, let's deploy a sample app. You can choose to install your own sample app into `mesh-apps` namespace by ignoring this step. In this demo we will install a custom swag store application. 

Run
```
make mesh-step6
```
This will install a sample app in the `mesh-apps` namespace. It will take a few minutes for all the pods to be deployed and go into `Running` state. Validate that all the pods are deployed and running by simply running 
```
kubectl get pods -n mesh-apps
```
and you will see the following. Note that all pods have 2 containers as this namespace has a label `istio-injection=enabled`

```
NAME                                     READY   STATUS    RESTARTS   AGE
adservice-8744f64bd-bbmz2                2/2     Running   0          62s
cartservice-6bc9b49975-4sq2m             2/2     Running   0          62s
checkoutservice-66965f79db-cb8nr         2/2     Running   0          62s
currencyservice-74bcdd8c58-2rnmn         2/2     Running   0          61s
emailservice-848bd6c94d-mbdsh            2/2     Running   0          61s
frontend-64776cfd7f-6s8bw                2/2     Running   0          61s
paymentservice-7f658cdf44-pbg5r          2/2     Running   0          61s
productcatalogservice-78d5ffb44d-vgk7f   2/2     Running   0          61s
recommendationservice-7bc9cf9d4-jfzp8    2/2     Running   0          60s
redis-cart-777db56c5f-th8cw              2/2     Running   0          60s
shippingservice-7ddbb47576-n7c26         2/2     Running   0          60s
```

As we also configured **Firefly** to issue all certs, let's inspect what the certificate in the workload looks like. 
Run
```
make print-svid
```
to see 
```
Pod name is frontend-7d9b98c747-bxb9d 
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            42:86:b7:92:a3:26:bf:00:b4:cd:26:c5:83:39:e7:c9
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=US, ST=TX, L=Frisco, O=CyberArk Inc, OU=Firefly Unit, CN=firefly-1-20250208113912 firefly-built-in-180.svc.cluster.local
        Validity
            Not Before: Feb  8 22:27:47 2025 GMT
            Not After : Feb  8 23:27:47 2025 GMT
        .....
        .....
             X509v3 Subject Alternative Name: 
                URI:spiffe://cluster.local/ns/mesh-apps/sa/frontend      
        .....
```

Note that the Issuer for the workload is **Firefly** and the accessing the UI will provide you addition information. The mesh identity is valid for 1 hour as defined by a policy in the Venafi Control Plane. Access Venafi Control Plane and the dashboard to review the metrics associated with this issuer. 

Test the app by simply running 

```
kubectl -n mesh-apps port-forward service/frontend 8120:80
```
and access the application on your browser as `http://localhost:8120`

## Optional Steps

If you have access to a domain and can create a DNS entry you can optionally complete steps 7, 8 and 9. The following steps will provide you a way to access the sample application using a publicly accessible DNS. 

**Pre-requisites**

- you are running this in a cluster where the istio ingress controller service has an external ip.  
- you have configured a public CA that can issue a certificate to the domain you have access to
- you have the ability to map the `external-ip` or `host` from the ingress gateway service to a domain  

### STEP 7 - **Optional**
If you prefer to access the sample application with a DNS that you can configure and access instead of doing a port-forward and using local host, we will need to configure the Istio Gateway resources. We also need a public certificate to access the Ingress Gateway. Venafi will issue a public certificate that is trusted by the browser. The certificate will be issued by a `VenafiClusterIssuer`. 
The template for issuer is located here [templates/cloud/venafi-cloud-publicca-cluster-issuer.yaml](templates/cloud/venafi-cloud-publicca-cluster-issuer.yaml) 
The template for certificate is located here [templates/cloud/venafi-cloud-managed-public-cert.yaml](templates/cloud/venafi-cloud-managed-public-cert.yaml)

There are two options for this step. Either using Venafi Cloud or the data center to issue a public certificate. You are also required to set the variable `CYBR_ZONE_PUBLIC_CA` and `CYBR_DOMAIN_FOR_SAMPLE_APP` The Zone is used for issuing a publicly trusted certificate. You can issue a private certificate if your browser configured to trust the CA. The DNS will be used to configured the Gateway.  The target to get a certificate from Venafi cloud is `mesh-step7-cloud` and from data center is `mesh-step7-tpp`

Run 
```
make mesh-step7-cloud
```
to create an issuer and certificate. You will see the following output 
```
❯ make mesh-step7-cloud
venaficlusterissuer.jetstack.io/venafi-publicca-cluster-issuer created
certificate.cert-manager.io/5419352604.example.com created
```

### STEP8- **Optional**
If you have completed STEP8 that means you have access to a valid DOMAIN and can add a record set. The demo is scripted to run `aws/map-dns-to-gateway.sh` Review the script and change it as you see fit. 
You will notice that the script retrieves the IP address from the ingress gateway service. Some environments will provide you a hostname and not ip. 
You are also **REQUIRED** to setup `cloud-settings.sh` and configure your AWS Route53 settings. Make sure you are authenticated to the account where you intend to add a DNS record. 

If you are to manually perform this step, basically, you need to run 
```
kubectl get svc istio-ingressgateway -n istio-system
```
and associate the provisioned loadblancer IP/hostname to your DNS. 
To automatically add an entry to AWS Rout53 for a domain you have access to, just run
```
make mesh-step8
```
and you will see

```
Create DNS entry for 3018580802.example.com to map to Gateway host/ip
Zone is AAAABBBBCCCCDDDD
DNS is 3018580802.example.com
{
    "ChangeInfo": {
        "Id": "/change/C064230619T9XHRGPQ6CF",
        "Status": "PENDING",
        "SubmittedAt": "2025-02-09T01:41:27.515000+00:00"
    }
}
```

### STEP 9 - **Optional**
If you have completed STEPS  7 and 8, you can create the required gateway resources. The gateway resource template is located here [templates/servicemesh/sample-app-gateway.yaml](templates/servicemesh/sample-app-gateway.yaml) Review the file. This will be used for creating a gateway resource that is mapped to the frontend sample service. 

Run 
```
make mesh-step9
```
and you will see
```
gateway.networking.istio.io/storefront-gateway created
virtualservice.networking.istio.io/storefront-virtualservice created
serviceentry.networking.istio.io/allow-egress-googleapis created
serviceentry.networking.istio.io/allow-egress-google-metadata created
virtualservice.networking.istio.io/frontend created
####################################################################################################
######### Sample apps takes about 60 seconds before pods are Ready in mesh-apps namespace ##########
######### Access application using https://3018580802.example.com/     ###
####################################################################################################
```
