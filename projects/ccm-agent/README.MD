# CyberArk Certificate Manager for discovering certificates in Kubernetes with Agent configured to use Federated Identity.

This demo shows how the discovery agent in CyberArk Certificate Manager for Kubernetes can be configured to use an OIDC provider for authenticating to CyberArk Certificate Manager.  

## Pre-requisites
- You have access to CyberArk Certificate Manager
- You have created "Discovery Agent - Allows a CyberArk Discovery Agent to connect to the Certificate Manager for Kubernetes" service account have chose "Workload Identity Federation" as the authentication method. The end result of the created service account looks like [this](./ccm-agent-oidc-discovery.png)
- Documentation is [here](https://docs.venafi.cloud/vaas/k8s-components/t-install-tlspk-agent/#step-3-create-a-service-account) 

## Running the demo 
Copy `env-vars-template.sh` as `env-vars.sh` and set the values for the variables

Run `./ccm_agent_oidc.sh` and you will see
```
❯ ./ccm_agent_oidc.sh
Usage: ./ccm_agent_oidc.sh {create-service-account|install-agent|clean}
```

### Creating Service accounts
As stated in the pre-requisite, create a service account from the UI. This demo will be updated at a later time to create it programatically. 

### Installing the agent.

Run `./ccm_agent_oidc.sh install-agent` and you will see
```
❯ ./ccm_agent_oidc.sh install-agent
Installing CyberArk Certificate Manager Kubernetes Agent with client ID: xxxxf0f9-xxxx-xxxx-xxxx-xxxxxxab5a1
Release "ccm-kubernetes-agent" does not exist. Installing it now.
Pulled: registry.venafi.cloud/charts/venafi-kubernetes-agent:v1.6.0
Digest: sha256:c163ed3b8bbedc2529959b52ac3e1178c0da10091d81b7ebdf2a7f17
NAME: ccm-kubernetes-agent
LAST DEPLOYED: Thu Jul 31 12:10:08 2025
NAMESPACE: cyberark
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
- Check the VenafiConnection exists: "cyberark/venafi-connection"
> kubectl get VenafiConnection -n cyberark venafi-connection
- Check the application is running:
> kubectl get pods -n cyberark -l app.kubernetes.io/instance=ccm-kubernetes-agent

- Check the application logs for successful connection to the platform:
> kubectl logs -n cyberark -l app.kubernetes.io/instance=ccm-kubernetes-agent
Helm install completed. Creating RBAC and Connection resources...
role.rbac.authorization.k8s.io/cyberark-agent-token-create-role created
rolebinding.rbac.authorization.k8s.io/cyberark-agent-token-create-role-binding created
venaficonnection.jetstack.io/venafi-connection created
Agent installation and configuration complete.
```

Check to see if the app is deployed and the pods are running
```
❯ kubectl get deploy -n cyberark
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
ccm-kubernetes-agent   1/1     1            1           76s
```

Check the logs to see if everything looks good by running

```
kubectl logs -n cyberark -l app.kubernetes.io/instance=ccm-kubernetes-agent
```
and you should see among other things

```
....
.....
......
I0731 17:01:38.498114       1 run.go:437] "Data sent successfully" logger="Run.gatherAndOutputData.postData"
```

Access the UI and go to Installations -> Kubernetes Clusters and you should see your cluster registered. All certificates in the cluster will be discoverd.

Additonally, access Settings -> Event Log and you will see "Service Account Access Token Granted" and "Kubernetes Cluster Automatically created" events. 
