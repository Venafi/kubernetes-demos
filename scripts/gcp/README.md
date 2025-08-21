# Script to build and destroy GKE cluster and Google Certificate Authority Service

## Pre-requisites 
- You have access to Google Cloud Platform 

## Setup
- Copy `env-vars-template.sh` to `env-vars.sh` 
- Set the correct values for `PROJECT_ID` and any other variables you prefer to change.

> **NOTE**: The cluster will created with access only from your local IP. You can always add addtional IP ranges in the variable `GKE_API_EXTRA_CIDRS`

## Authenticate 
Run `./gcp-login.sh` and you will be authenticated in the CLI

```
❯ ./gcp-login.sh
Reauthentication required.
Please enter your password:

Reauthentication successful.
Updated property [core/project].
Updated property [compute/region].
Already logged in to gcloud.
Setting up Application Default Credentials...
Your browser has been opened to visit:

    https://accounts.google.com/o/oauth2/auth?.................

Credentials saved to file: [/Users/sitaram.iyer/.config/gcloud/application_default_credentials.json]

These credentials will be used by any library that requests Application Default Credentials (ADC).

Quota project "XXXXXXXXXXX" was added to ADC which can be used by Google client libraries for billing and quota. Note that some services may still bill the project owning the resource.


Updates are available for some Google Cloud CLI components.  To install them,
please run:
  $ gcloud components update

gcp-login.sh: ready (project=XXXXXXXXXXX, region=us-central1, zone=n/a)

```

## Create Cluster

Just running `./gke-cluster.sh` will show the usage information
```
❯ ./gke-cluster.sh
Updated property [core/project].
Updated property [compute/region].
Already logged in to gcloud.
gcp-login.sh: ready (project=XXXXXXXXXXX, region=us-central1, zone=n/a)
Usage: ./gke-cluster.sh {create|delete|status|authorize-ip|show-allowed-ip}

Environment (set in env-vars.sh):
  LOCAL_IP_CMD            Command to detect your public IP (with fallbacks).
  LOCAL_IP                Cached public IP value.
  GKE_API_AUTHORIZED_IPS  Comma-separated CIDRs, default "${LOCAL_IP}/32".
  GKE_API_EXTRA_CIDRS     Optional extra CIDRs to allow (comma-separated).

Examples:
  ./gke-cluster.sh create
  GKE_API_EXTRA_CIDRS="203.0.113.0/24" ./gke-cluster.sh authorize-ip
  ./gke-cluster.sh show-allowed-ip
```

To create a new cluster 

Run 
```
./gke-cluster.sh create
```

You will see the following output 
```
❯ ./gke-cluster.sh create
Updated property [core/project].
Updated property [compute/region].
Already logged in to gcloud.
gcp-login.sh: ready (project=XXXXXXXXXXX, region=us-central1, zone=n/a)
Locking API server to: xxx.xxx.xxx.xxx/32
Checking if cluster 'gke-dev-01' exists...
Creating GKE cluster 'gke-dev-01'...
Note: The Kubelet readonly port (10255) is now deprecated. Please update your workloads to use the recommended alternatives. See https://cloud.google.com/kubernetes-engine/docs/how-to/disable-kubelet-readonly-port for ways to check usage and for migration instructions.
Note: Your Pod address range (`--cluster-ipv4-cidr`) can accommodate at most 1008 node(s).
Creating cluster gke-dev-01 in us-central1... Cluster is being configured...⠧    
....
Created [https://container.googleapis.com/v1/projects/XXXXXXXXXXX/zones/us-central1/clusters/gke-dev-01].
To inspect the contents of your cluster, go to: https://console.cloud.google.com/kubernetes/workload_/gcloud/us-central1/gke-dev-01?project=XXXXXXXXXXX
kubeconfig entry generated for gke-dev-01.
NAME        LOCATION     MASTER_VERSION      MASTER_IP        MACHINE_TYPE   NODE_VERSION        NUM_NODES  STATUS   STACK_TYPE
gke-dev-01  us-central1  1.33.2-gke.1240000  xxx.xxx.xxx.xxx  e2-standard-4  1.33.2-gke.1240000  9          RUNNING  IPV4
Fetching kubeconfig for 'gke-dev-01'...
Fetching cluster endpoint and auth data.
kubeconfig entry generated for gke-dev-01.

```

You can additionally check the status of your GKE cluster by simply running `./gke-cluster.sh status`

```
❯ ./gke-cluster.sh status
Updated property [core/project].
Updated property [compute/region].
Already logged in to gcloud.
gcp-login.sh: ready (project=XXXXXXXXXXX, region=us-central1, zone=n/a)
NAME        LOCATION     STATUS   CHANNEL
gke-dev-01  us-central1  RUNNING  REGULAR
```

## Create and configure Google Certificate Authority Service

- Set the `DNS_NAME` variable to something that you prefer. The default is `example.com`
- For cert-manager Google CAS Issuer install in the future , the default value for namespace is set to `cert-manager`. If your namespace is different set the value accordingly to make sure that the Workload Identity User binding is correctly configured. 

Simply running `./cas.sh` will show the usage 

```
❯ ./cas.sh
Updated property [core/project].
Updated property [compute/region].
Already logged in to gcloud.
gcp-login.sh: ready (project=XXXXXXXXXXX, region=us-central1, zone=n/a)
Usage: ./cas.sh {create|delete|status}

Env toggles for deletion:
  CAS_DELETE_ISSUED_CERTS=true|false   # default true; revoke+delete issued certs first
  CAS_SKIP_GRACE_PERIOD=true|false     # default false; if true, immediately delete CA (skip 30-day grace)
  CAS_IGNORE_ACTIVE_CERTS=true|false   # default false; add only if you want to force-delete with active certs

Examples:
  CAS_DELETE_ISSUED_CERTS=true CAS_SKIP_GRACE_PERIOD=true ./cas.sh delete
```

Run `./cas.sh create` to create a private CA.
If you have previously created a CA Pool with the name that you are using again, it's OK as long as you haven't deleted it. GCP does not allow reusing a deleted CaPool Id. Just set the values of CaPool and CAS (not really required) with a suffic like 001 or something. 

You will see
```
❯ ./cas.sh create
Updated property [core/project].
Updated property [compute/region].
Already logged in to gcloud.
gcp-login.sh: ready (project=XXXXXXXXXXX, region=us-central1, zone=n/a)
Ensuring CAS pool 'mis-demo-pool-001' (tier=devops)...
Creating CA Pool....done.                                                                                                                                            
Created CA Pool [projects/XXXXXXXXXXX/locations/us-central1/caPools/mis-demo-pool-001].
Ensuring root CA 'mis-demo-cas--001' in pool 'mis-demo-pool-001'...
Creating Certificate Authority....done.                        
.....
.....
.....

```

If you run `./cas.sh status` you will see the CApools and the private CA's.

```
❯ ./cas.sh status
Updated property [core/project].
Updated property [compute/region].
Already logged in to gcloud.
gcp-login.sh: ready (project=XXXXXXXXXXX, region=us-central1, zone=n/a)
NAME               LOCATION  TIER
mis-demo-pool-001            DEVOPS

NAME               STATE
mis-demo-cas--001  ENABLED
```

## Cleaning up

### Delete the Certificate Authority Service
- run `./cas.sh delete`

You will see
```
❯ ./cas.sh delete
Updated property [core/project].
Updated property [compute/region].
Already logged in to gcloud.
gcp-login.sh: ready (project=XXXXXXXXXXX, region=us-central1, zone=n/a)
Revoking and deleting issued certificates for CA 'mis-demo-cas--001' in pool 'mis-demo-pool-001' (location 'us-central1')...
No issued certificates found for this CA.
Disabling root CA 'mis-demo-cas--001' (if exists)...
Disabling Root CA...done.                                                                                                                                            
Disabled Root CA [projects/XXXXXXXXXXX/locations/us-central1/caPools/mis-demo-pool-001/certificateAuthorities/mis-demo-cas--001].
Removing IAM bindings (best-effort)...
Updated IAM policy for serviceAccount [google-cas-issuer@oXXXXXXXXXXX.iam.gserviceaccount.com].
etag: BwY81awePmg=
version: 1
Updated IAM policy for CA Pool [mis-demo-pool-001].
etag: BwY81aw18j0=
version: 1
Deleting root CA 'mis-demo-cas--001'...
Deleting Root CA...done.                                                                                                                                             
Deleted Root CA [projects/XXXXXXXXXXX/locations/us-central1/caPools/mis-demo-pool-001/certificateAuthorities/mis-demo-cas--001]. CA can not be undeleted.
Deleting pool 'mis-demo-pool-001'...
Deleting the CA pool...done.                                                                                                                                         
Deleted the CA pool [projects/XXXXXXXXXXX/locations/us-central1/caPools/mis-demo-pool-001].
Deleting service account 'google-cas-issuer@XXXXXXXXXXX.iam.gserviceaccount.com'...
deleted service account [google-cas-issuer@XXXXXXXXXXX.iam.gserviceaccount.com]
```

### Delete the GKE Cluster
- run `./gke-cluster.sh delete`

```
❯ ./gke-cluster.sh delete
Updated property [core/project].
Updated property [compute/region].
Already logged in to gcloud.
gcp-login.sh: ready (project=XXXXXXXXXXX, region=us-central1, zone=n/a)
Deleting GKE cluster 'gke-dev-01'...
Deleting cluster gke-dev-01...⠹  
Deleting cluster gke-dev-01...done.
Deleted [https://container.googleapis.com/v1/projects/XXXXXXXXXXX/zones/us-central1/clusters/gke-dev-01].
```

