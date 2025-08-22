# Script to build and destroy EKS cluster

## Pre-requisites 
- You have access to a AWS Account
- Copy `env-vars-template.sh` to `env-vars.sh` 
- Set the CLUSTER_NAME, PROFILE, NODEGROUP_NAME, TAGS as needed. Rest can be default


## Usage
Just running `./eks-cluster.sh` will show the following
```
❯ ./eks-cluster.sh
Usage: ./eks-cluster.sh {create|delete|status} [--config ./env-vars.sh] [--force]

```
## Creating a cluster
If you have followed the pre-requisites and created a `env-vars.sh` then you don't need to pass `--config`. If your variables are in a file named different then pass `--config` with your config file name.

Simply run `./eks-cluster.sh create` to see the following 

```
❯ ./eks-cluster.sh create
📄 Using config file: ./env-vars.sh
🔐 Verifying AWS authentication (profile: default, region: us-east-2)...
🚀 Creating EKS cluster 'my-eks' in region 'us-east-2'...
🧱 Running: eksctl create cluster --name my-eks --version 1.33 --region us-east-2 --nodegroup-name my-workers --node-type t3.medium --nodes 4 --nodes-min 3 --nodes-max 4 --profile sitaram --tags CreatedBy=Sitaram,Environment=dev,Team=platform --with-oidc --managed
2025-08-22 12:53:24 [ℹ]  eksctl version 0.212.0-dev+db83da480.2025-07-29T20:05:26Z
2025-08-22 12:53:24 [ℹ]  using region us-east-2
.....
.....
.....
2025-08-22 13:07:43 [✔]  created 1 managed nodegroup(s) in cluster "my-eks"
2025-08-22 13:07:43 [ℹ]  kubectl command should work with "/Users/<user>/.kube/config", try 'kubectl get nodes'
2025-08-22 13:07:43 [✔]  EKS cluster "my-eks" in "us-east-2" region is ready
```

## Status check

To check the status of the cluster you can run `./eks-cluster.sh status` anytime. 

```
❯ ./eks-cluster.sh status
📄 Using config file: ./env-vars.sh
🔐 Verifying AWS authentication (profile: sitaram, region: us-east-2)...
🔍 Cluster status for 'my-eks' in region 'us-east-2'...
{
  "name": "my-eks",
  "status": "ACTIVE",
  "version": "1.33",
  .....
  .....
  .....
}

🔐 OIDC Identity Provider:
https://oidc.eks.us-east-2.amazonaws.com/id/XXXXXXXXXXXXXXXXXXXXX

```

## Adding a Windows NodeGroup

To add a windows node group to the cluster that was just created, 

- Review `env-vars-win.sh` and change as needed. You don't neccessarily need to change anything in this file. 

Run `./eks-windows-node.sh add` and after some time (it'll take a while to provision a windows machine),  you will see

```
❯ ./eks-windows-node.sh add
📄 Using config: ./env-vars.sh
🔐 Verifying AWS authentication (profile: default, region: us-east-2)...
🔧 Ensuring Windows networking prerequisites…
🔎 Discovering cluster IAM role name from EKS API…
✅ Discovered cluster role: eksctl-my-eks-cluster-ServiceRole-fzmN72xxxxxx
ℹ️  IAM policy already attached to 'eksctl-my-eks-cluster-ServiceRole-fzmN72xxxxxx'.
📝 Patching amazon-vpc-cni ConfigMap…
configmap/amazon-vpc-cni patched
🔎 Effective values:
true false
✅ Windows networking prerequisites ensured.
🪟 Creating managed Windows node group 'my-win-worker'…
.....
.....
.....
2025-08-22 13:18:43 [ℹ]  nodegroup "my-win-worker" has 1 node(s)
2025-08-22 13:18:43 [ℹ]  node "ip-xxx-xxx-xxx-xxx.us-east-2.compute.internal" is ready
2025-08-22 13:18:43 [✔]  created 1 managed nodegroup(s) in cluster "my-eks"
2025-08-22 13:18:43 [ℹ]  checking security group configuration for all nodegroups
2025-08-22 13:18:43 [ℹ]  all nodegroups have up-to-date cloudformation templates
ℹ️  Target Windows workloads with: spec.nodeSelector: { kubernetes.io/os: windows }

```

## Testing Windows node

Run `./eks-windows-node.sh test` to create a pod in the Windows node.
You will see
```
❯ ./eks-windows-node.sh test
📄 Using config: ./env-vars.sh
🔐 Verifying AWS authentication (profile: default, region: us-east-2)...
🧪 Deploying sample Windows pod…
pod/my-win-pod created
⏳ Waiting up to 5m for pod to be Ready…
NAME         READY   STATUS    RESTARTS   AGE   IP              NODE                                          NOMINATED NODE   READINESS GATES
my-win-pod   1/1     Running   0          7s    xxx.xxx.xxx.xxx   ip-xxx-xxx-xxx-xxx.us-east-2.compute.internal   <none>           <none>
✅ Windows node validated.
```

When you run the test for the first time, it's going to take sometime to pull the image. After the pod is deployed, 
run `kubectl describe pod my-win-pod`

to see 
```
Events:
  Type    Reason             Age   From                     Message
  ----    ------             ----  ----                     -------
  Normal  Scheduled          12s   default-scheduler        Successfully assigned default/my-win-pod to ip-xxx-xxx-xxx-xxx.us-east-2.compute.internal
  Normal  ResourceAllocated  12s   vpc-resource-controller  Allocated Resource vpc.amazonaws.com/PrivateIPv4Address: xxx.xxx.xxx.xxx/19 to the pod
  Normal  Pulled             9s    kubelet                  Container image "mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2022" already present on machine
  Normal  Created            8s    kubelet                  Created container: my-container
  Normal  Started            6s    kubelet                  Started container my-container
```

Delete the test pod by running `kubectl delete pod my-win-pod`

## Delete the cluster and cleanup

To delete the cluster and remove all resources run `./eks-cluster.sh delete`

This will remove all nodegroups, cluster, VPC, etc..

```
❯ ./eks-cluster.sh delete
📄 Using config file: ./env-vars.sh
🔐 Verifying AWS authentication (profile: default, region: us-east-2)...
⚠️ About to delete cluster 'my-eks'. Use --force to skip this prompt.
Type 'yes' to continue: yes
🔥 Deleting EKS cluster 'my-eks'...
2025-08-22 13:55:10 [ℹ]  deleting EKS cluster "my-eks"
2025-08-22 13:55:11 [ℹ]  will drain 0 unmanaged nodegroup(s) in cluster "my-eks"
2025-08-22 13:55:11 [ℹ]  starting parallel draining, max in-flight of 1
2025-08-22 13:55:11 [ℹ]  deleted 0 Fargate profile(s)
2025-08-22 13:55:12 [✔]  kubeconfig has been updated
2025-08-22 13:55:12 [ℹ]  cleaning up AWS load balancers created by Kubernetes objects of Kind Service or Ingress
2025-08-22 13:55:14 [ℹ]  
4 sequential tasks: { 
    2 parallel sub-tasks: { 
        delete nodegroup "my-win-workers",
        delete nodegroup "my-workers",
    }, delete IAM OIDC provider, delete addon IAM "eksctl-my-eks-addon-vpc-cni", delete cluster control plane "my-eks" 
}
2025-08-22 13:55:14 [ℹ]  will delete stack "eksctl-my-eks-nodegroup-my-workers"
2025-08-22 13:55:14 [ℹ]  waiting for stack "eksctl-my-eks-nodegroup-my-workers" to get deleted
2025-08-22 13:55:14 [ℹ]  waiting for CloudFormation stack "eksctl-my-eks-nodegroup-my-workers"
2025-08-22 13:55:14 [ℹ]  will delete stack "eksctl-my-eks-nodegroup-my-win-workers"
2025-08-22 13:55:14 [ℹ]  waiting for stack "eksctl-my-eks-nodegroup-my-win-workers" to get deleted
....
....
....
....
2025-08-22 14:04:00 [ℹ]  will delete stack "eksctl-my-eks-cluster"
2025-08-22 14:04:00 [ℹ]  waiting for stack "eksctl-my-eks-cluster" to get deleted
2025-08-22 14:04:00 [ℹ]  waiting for CloudFormation stack "eksctl-my-eks-cluster"
2025-08-22 14:06:01 [ℹ]  waiting for CloudFormation stack "eksctl-my-eks-cluster"
2025-08-22 14:06:01 [✔]  all cluster resources were deleted
```