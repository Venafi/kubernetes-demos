# Steps to setup Kubernetes Discovery and Context Service

This guide will walk through setting up kubernetes discovery and context in CyberArk platform 

## Pre-requisites

Access CyberArk Identity Administration and create a service account user. You will need the service account user id and password. The service account user will be a OAuth client. 

## Step 1
Copy the environment template file to configure the variables.

```
cp env-vars-template.sh env-vars.sh
```

Review `env-vars.sh` and update the variables. Values starting with "REPLACE_" must be set. 
Optionally, set the cluster name and description of your choice

## Step 2 [Create a cluster]
If you have an existing cluster, ignore this. If you need a demo cluster, simply run the following. Assumes you have `kind` installed on your machine. 

```
kind create cluster --name discovery-demo-cluster --wait 2m
```

## Step 3 [Install the discovery agent]

Review the `discovery-svc.sh` if you choose to. To install the agent, simply run

```
./discovery-svc.sh install-agent 
```

Access Discovery and Context service and you should see at least one secret. If you want more secrets just run 
```
create-sample-data.sh 
```
and wait for the secrets to show up in the UI. The number of sample secrets you want to create can be configured in `env-vars.sh`

## Step 4 [Uninstall agent]

To un-install the agent from the cluster, run 
```
./discovery-svc.sh clean
```


## Delete the cluster
To remove the cluster, run 

```
 kind delete cluster --name discovery-demo-cluster
```

