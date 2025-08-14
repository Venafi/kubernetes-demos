# Script to build and destroy AKS cluster

## Pre-requisites 
- You have access to a Azure tenant and subscription

## Setup
- Copy `env-vars-template.sh` to `env-vars.sh` 
- Set the correct values for `AZ_TENANT_ID` and `AZ_SUBSCRIPTION_ID`
- Optionally set the cluster name and tags as needed. 

## Authenticate 
Run `./azure-login.sh` and you will be authenticated in the CLI

## Create Cluster
Run 
```
./aks-cluster.sh create
```

> **NOTE**: The cluster is created with access only from your local IP. You can always add addtional IP ranges in the variable `AKS_API_AUTHORIZED_IPS`

> **NOTE**: If your local IP changes after you create the cluster, simply re-run `./aks-cluster.sh create` the resource groups and the security rules will be updated with the new IP. 

## Delete cluster 
Run `./aks-cluster.sh delete` and you will see 
```
==> Checking required CLIs...
==> Verifying Azure login state...
==> Deleting AKS cluster: ski-aks
==> Deleting resource group: ski-aks-rg
==> Done.
```

