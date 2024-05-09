# Setting up certificate discovery in Kubernetes cluster

This readme is written to install only the discovery agent to discover certificates from a Kuberentes cluster and bring it to Venafi Control Plane. 

## Requirements  
- You have access to the [Venafi Control Plane](!https://ui.venafi.cloud) 

## Pre-requisites 

Before you start, there are some requirements to setup the environment.
The demos use a `Makefile` for all operations. Always review the target you are asked to execute. If you prefer to adapt it to another tool, please do. 

- Copy file `vars-template.sh` as `vars.sh`. The `Makefile` uses `vars.sh` to load your specific settings.

    > Replace the value for `VEN_CLOUD_API_KEY` with the value of `apiKey` from your Venafi Control Plane. If you don't have one, ask your administrator

    > Replace the value for `VEN_TEAM_NAME` with a team name created in your Venafi Control Plane. If you don't know what to use for the team name, ask your administrator

    > Replace the value for `VEN_CLUSTER_NAME` with any name that represets that cluster in which the discovery agent will be installed. 

    > Replace the value for `VEN_SVC_ACC_VALIDITY_DAYS` with a numeric value that represents that number of days you want the service account associated with discovery to be valid. You can leave the default value as is if 180 days is OK with you. 

# Install discovery agent in cluster. 

## STEP 1
- Before you begin, run `make install-venctl` to install the Venafi CLI tool to manage creation of service accounts. We frequently release new version of `venctl`. You can run `make install-venctl` as frequently as you want. If a new version is detected, it will upgrade itself. 

## STEP 2
- Run `make init` to create a service account, create the required namespaces and configure them. You can create a service account for each cluster or create it one time and use the associated `client-id` and `secret` for all the clusters. 

 The output of running `make init` will look like as below

 ```
 ❯ make init
Service account for certificate discovery
Creating a new service account for the Venafi Kubernetes Agent
 ✅    Running prerequisite checks
Service Account id=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Service account was created successfully file=artifacts/venafi-install/venafi_agent_secret.json format=secret
namespace/venafi created
Credentials for certificate discovery
secret/agent-credentials created
 ```

 Note that in addition to creating a service account in the Venafi Control Plane, a namespace called `venafi` is created and a `secret` called `agent-credentials` is created that holds the private key associated with the service account. 

 The `client_id` associated with the service account is written to a file called `venafi_agent_client_id`. If you don't use the CLI and prefer to create a service account in the UI, you don't need to run `make init`. However, you will still need to create the `agent-credentials` with the secret provided in the UI. The recommended approach is to use the CLI as it makes automation simpler. 

## STEP 3

To install the Venafi Kubernetes Agent simply run 
```
make install-agent
```

This will install the Venafi Kubernetes agent in your cluster.  Optionally, if you want to pass additional Helm values run `helm template` separately with the and change the command to use your helm values. 

Running `make install-agent` will install the agent in the `venafi` namespace and will register the cluster in Venafi Control Plane. 

## STEP 4

To optionally clean up , just run `make clean` 

# Addtional details

Detailed documentation about the agent, network requirements and troubleshooting is documented [here](!https://docs.venafi.cloud/vaas/k8s-components/t-install-tlspk-agent/)

If the Helm install fails, change `helm upgrade` to `helm template`, generate the resources in a temporary directly and apply the resources. If something fails we will know which resource is failing to install. 
