# Creating ROSA HCP Cluster

## Pre-requisites
- You have access to AWS
- You have access to Redhat 
- Your AWS account is connected to Redhat subscription (needed for HCP ROSA)

## Creating a OpenShift Cluster. 
Creating a OpenShift cluster is done via multiple steps. We need to create the appropriate VPCs, the corrrect IAM roles, etc. 

> **NOTE** Copy `env-vars-template.sh` as `env-vars.sh` and set the variables. Should be pretty straightforward.  

### Step 1
We will deploy a Cloud Formration template that will create the relevant VPC's and subnets. As this is a Cloud Formation template we will be able to easily tear it down when we destroy the cluster after use. 

To create the network just run `./01.create-rosa-network.sh` and ypu will see

```
❯ ./01.create-rosa-network.sh
🚀 Creating network stack via ROSA CLI: my-rosa-nw-stack in us-east-2
I: No template name provided in the command. Defaulting to rosa-quickstart-default-vpc. Please note that a corresponding directory with this name must exist under the specified path <`--template-dir`> or the templates directory for the command to work correctly. 
INFO[0001] Creating CloudFormation client               
INFO[0001] Creating CloudFormation stack                
INFO[0013] --------------------------------------------- 
..................
..................
..................
INFO[0133] Stack my-rosa-nw-stack created            
🔍 Retrieving subnet IDs from CloudFormation stack: my-rosa-nw-stack
📄 Subnet IDs written to subnet-ids-my-rosa.env
🏷️ Tagging public subnet subnet-xxxxxxxxxxxxxxxxx
🏷️ Tagging private subnet subnet-xxxxxxxxxxxxxxxxx
✅ Network creation using CloudFormation and subnet tagging complete. subnet-ids-my-rosa.env will be sourced during cluster creation and used for --subnet-ids.
```

### Step 2
We will now create all the required IAM roles in the AWS account in preparation for the cluster creation. 
Run `./02.setup-rosa-iam.sh` to create the IAM roles

You will see
```
❯ ./02.setup-rosa-iam.sh
🚀 [1/3] Creating ROSA account roles...
W: Region flag will be removed from this command in future versions
I: Logged in as 'xxxxxx-xxxxxx' on 'https://api.openshift.com'
I: Validating AWS credentials...
I: AWS credentials are valid!
I: Validating AWS quota...
I: AWS quota ok. If cluster installation fails, validate actual AWS resource usage against https://docs.openshift.com/rosa/rosa_getting_started/rosa-required-aws-service-quotas.html
I: Verifying whether OpenShift command-line tool is available...
I: Current OpenShift Client Version: 4.18.11
I: Creating account roles
.........
.........
.........
🚀 [2/3] Creating OIDC config (managed)...
✅ OIDC Config ID: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
🚀 [3/3] Creating operator roles for ROSA HCP...
W: Region flag will be removed from this command in future versions
I: Reusable OIDC Configuration detected. Validating trusted relationships to operator roles: 
I: Creating roles using 'arn:aws:iam::xxxxxxxxxxx:role/AWSReservedSSO_AdministratorAccess_xxxxxxxxxx'
.........
.........
✅ ROSA IAM pre-reqs are complete.
```

## Step 3
With all the pre-requisites in place, we can create a cluster. Cluster creation will take some time. There are a few actions that needs to be performed after the cluster is created. The actions are specific to locking in ingress rules to specific IP. The local IP as opposed to allowing `0.0.0.0` 

Simply running `./03.create-rosa-cluster.sh` will show 

```
Usage: ./03.create-rosa-cluster.sh [option]
Options:
  update-security-groups   Only patch security groups
  status                   Check cluster readiness
  full-setup               Run full flow: create + status + patch
```

We will run `./03.create-rosa-cluster.sh full-setup` . Occasionally you will see the token to access RedHat would expire. You will be notified and asked to login using `rosa` 

You will see
```
❯ ./03.create-rosa-cluster.sh full-setup
🚀 Creating public ROSA HCP cluster using tagged public + private subnets...
I: cluster admin user is cluster-admin
I: cluster admin password is xxxxxxxxxxxxxx
I: Using 'xxxxxxxxxxxx' as billing account
I: To use a different billing account, add --billing-account xxxxxxxxxx to previous command
W: Account roles not created by ROSA CLI cannot be listed, updated, or upgraded.
....
....
I: Creating cluster 'my-rosa'
I: To view a list of clusters and their status, run 'rosa list clusters'
I: Cluster 'my-rosa' has been created.
.....
.....
✅ Cluster creation command submitted.
⏳ Waiting for cluster to reach 'ready' state...
🔄 Current status: waiting. Sleeping 60s...
🔄 Current status: validating. Sleeping 60s...
🔄 Current status: validating. Sleeping 60s...
🔄 Current status: validating. Sleeping 60s...
🔄 Current status: installing. Sleeping 60s...
🔄 Current status: installing. Sleeping 60s...
✅ Cluster is ready.
🔍 Starting SG patch process using tag: api.openshift.com/name = my-rosa
✅ Found security groups: sg-xxxxxxxxxxxxxxxxx	sg-xxxxxxxxxxxxxxxxx

🔧 Patching security group: sg-xxxxxxxxxxxxxxxxx
   🔎 Checking port 443 for CIDR xxx.xxx.xxx.xxx/32
   ➕ Adding rule for port 443 to allow xxx.xxx.xxx.xxx/32
......
......
......
✅ Security group patching complete. Log saved to patch-sg-rules.log
🕒 Total elapsed time: 11 min 46 sec
```

The status check will continue till the cluster is ready or the token expires. If the token expires you will see specific instructions to continue.

> **NOTE** - After the cluster is created a bunch of security groups are updated to only allow access from the local IP as opposed to `0.0.0.0` 

### Cleanup 
To cleanup simply run `./04.clean-rosa.sh`

```
./04.clean-rosa.sh
❯ ./04.clean-rosa.sh
💥 Starting ROSA cleanup for cluster: my-rosa (profile: xxxxxxx)
.....
.....
⏳ Waiting for cluster to be deleted...
   🔄 Cluster still exists... sleeping 60s
   🔄 Cluster still exists... sleeping 60s
.....
✅ Cluster deleted.
....
.....
I: Successfully deleted the operator roles
.....
.....
I: Successfully deleted the classic account roles
.....
.....
.....
I: Successfully deleted the hosted CP account roles
.....
.....
🧹 Deleting CloudFormation stack: my-rosa-nw-stack
⏳ Waiting for stack to be deleted...
✅ Stack my-rosa-nw-stack successfully deleted.
✅ Deleted kubeconfig files

✅ ROSA cleanup complete.

```
