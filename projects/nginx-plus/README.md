# NGINX Plus with CyberArk Certificate Manager Demo

This project demonstrates deploying the **NGINX Plus Ingress Controller** and integrating it with **CyberArk Certificate Manager for Kubernetes** .

## Overview

The workflow is organized into step-by-step scripts:

1. **01.install-nginx.sh** – Installs NGINX Plus Ingress Controller in your cluster.
2. **02.validate-nginx.sh** – Deploys a sample echo service and validates HTTP routing through the ingress.
3. **03.install-ccm.sh** – Installs CyberArk Certificate Manager components (cert-manager, CCM connection and Enhanced issuer).
4. **04.validate-ccm.sh** – Validates certificate issuance using a namespaced and/or cluster issuer.
5. **05.create-virtual-server.sh** – Creates three VirtualServers in the sandbox namespace:
   - VS1 uses a TLS secret from a pre-created certificate (label `app=sample1`).
   - VS2 uses inline `tls.cert-manager.issuer` configuration with the namespaced issuer.
   - VS3 uses `tls.cert-manager.cluster-issuer` configuration with the cluster issuer.
6. **06.cleanup.sh** – Cleans up all resources, issuers, connections, CRDs, and namespaces.

---

## Getting Started

### Configure Environment Variables

Make a copy of the template and update values:

```bash
cp env-vars-template.sh env-vars.sh
```

Edit `env-vars.sh` with your configuration. Everything except those marked as **required** can be left alone.

### Configuration Variables

| Variable Name | Description | Default Value | Required |
|---------------|-------------|---------------|----------|
| NAMESPACE | Namespace where NGINX is installed | nginx-ingress | optional |
| RELEASE_NAME | NGINX Helm chart release name  | nginx-plus | optional |
| APP_NS | Sample namespace for VirtualServers and Certificates | sandbox | optional |
| NGINX_PLUS_CHART | OCI Chart location | oci://ghcr.io/nginx/charts/nginx-ingress | optional |
| NGINX_PLUS_VERSION | Helm Chart version | 2.3.0 | optional |
| IMG_REPO | NGINX Image Location | private-registry.nginx.com/nginx-ic/nginx-plus-ingress | optional |
| PULL_SECRET_NAME | Name of the image pull secret for NGINX | regcred | optional |
| LICENSE_SECRET_NAME | Name of the license secret name | license-token | optional |
| JWT_FILE | Update to set the path to downloaded JWT file from F5 | <PATH-TO>/nginx-one-eval.jwt | required |
| CRT_FILE | Update to set the path to downloaded CRT file from F5 | <PATH-TO>/nginx-one-eval.crt | required |
| KEY_FILE | Update to set the path to downloaded KEY file from F5 | <PATH-TO>/nginx-one-eval.key | required |
| APP_NAME | Sample deployment name in sandbox namespace | echo | optional |
| APP_IMAGE | Image for sample deployment | ealen/echo-server:latest | optional |
| VS_NAME | Virtual Server Name for quick test | demo-vs | optional |
| DNS_BASE_DOMAIN: | Your domain name | example.com | required |
| DNS_SUFFIX: | Sample suffix | current datetime | optional |
| DNS_NAME: |  suffix + DNS_BASE_DOMAIN for certs | nginx-<suffix>.DNS_BASE_DOMAIN | optional |
| CCM_NAMESPACE | Namespace where Cyberark components are installed | cyberark | optional |
| CCM_CLOUD_REGION | Cyberark Certificate Manager Region | us | optional |
| CCM_APIKEY | API Key for your CyberArk Certificate Manager Tenant | REPLACE_WITH_API_KEY | required |
| CERT_ZONE | Zone from your CyberArk Certificate Manager to issue certs | CloudApps\\Default | required |
| CCM_REGISTRY_SVC_ACCT_NAME | Name of the OCI registry serivce account in Certificate Manager | cyberark-nic-test-sa | optional |
| CCM_TEAM_NAME | Name of the Team to associaate with service account (MUST PRE_EXIST) | platform-admin | required |
| TMP_ARTIFACTS_DIR | Location where temporary files are created | ${HOME}/tmp/nginx-test | optional |


---

### Step 1 – Install NGINX Plus

```bash
./01.install-nginx.sh
```

This will deploy the NGINX Plus Ingress Controller into the namespace defined in `NAMESPACE` and configure it with your license and registry secrets. cert-manager integration is enabled automatically.

You should see
```
.....
.....
NAME: nginx-plus
LAST DEPLOYED: Fri Sep 19 14:46:35 2025
NAMESPACE: nginx-ingress
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
NGINX Ingress Controller 5.2.0 has been installed.

For release notes for this version please see: https://docs.nginx.com/nginx-ingress-controller/releases/

Installation and upgrade instructions: https://docs.nginx.com/nginx-ingress-controller/installation/installing-nic/installation-with-helm/
>> Waiting for controller to be Available...
deployment.apps/nginx-plus-nginx-ingress-controller condition met
>> install-nginx.sh complete.
```

Confirm that you have a valid IP by running
```
kubectl get svc -n nginx-ingress
```
and you should see

```
❯ k get svc -n nginx-ingress
NAME                                  TYPE           CLUSTER-IP    EXTERNAL-IP      PORT(S)                      AGE
nginx-plus-nginx-ingress-controller   LoadBalancer   10.0.120.21   xxx.xxx.xxx.xxx   80:32370/TCP,443:31712/TCP   42s

```

### Step 2 – Validate HTTP Routing

```bash
./02.validate-nginx.sh
```

Deploys a sample `echo` service and exposes it through a VirtualServer. Use the printed curl command to test.
You should see 
```
❯ ./02.validate-nginx.sh
>> Ensuring app namespace sandbox
namespace/sandbox created
deployment.apps/echo created
service/echo created
>> Waiting for echo deployment to be Ready...
Waiting for deployment "echo" rollout to finish: 0 of 1 updated replicas are available...
deployment "echo" successfully rolled out
>> Applying VirtualServer demo-vs (host nginx-1714501909.svc.cluster.local)
virtualserver.k8s.nginx.org/demo-vs created
>> VirtualServer status:
NAME      STATE   HOST                                 IP               EXTERNALHOSTNAME   PORTS      AGE
demo-vs   Valid   nginx-1714501909.svc.cluster.local   xxx.xxx.xxx.xxx                     [80,443]   0s
>> Discovering controller LoadBalancer address...

>> Test HTTP routing with:
curl -i -H "Host: nginx-1714501909.svc.cluster.local" http://xxx.xxx.xxx.xxx/
>> Simple NGINX Plus validation complete.

```
**Run the test command** to see

```
❯ curl -i -H "Host: nginx-1714501909.svc.cluster.local" http://xxx.xxx.xxx.xxx/
HTTP/1.1 200 OK
Server: nginx/1.29.0
Date: Fri, 19 Sep 2025 19:51:24 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 1254
Connection: keep-alive
ETag: W/"4e6-I/ykx6TJhH1V08kQWOQNoFJSkIc"

{"host":{"hostname":"nginx-1714501909.svc.cluster.local","ip
.....
.....
```

This confirms your NGINX Plus install is working as expected. 

### Step 3 – Install CyberArk Certificate Manager

```bash
./03.install-ccm.sh
```

Installs the necessary CyberArk Certificate Manager and Venafi components into the `CCM_NAMESPACE`.

Once the installation is complete you should see the following on the screen. 

```
❯ ./03.install-ccm.sh
>> Creating CCM Registry service account: cyberark-nic-test-sa
....
....
....
UPDATED RELEASES:
NAME                     NAMESPACE   CHART                                  VERSION   DURATION
venafi-connection        cyberark    venafi-charts/venafi-connection        v0.4.0          3s
cert-manager             cyberark    venafi-charts/cert-manager             v1.18.2        36s
venafi-enhanced-issuer   cyberark    venafi-charts/venafi-enhanced-issuer   v0.16.0        21s
```

### Step 4 – Validate Certificate Issuance

```bash
./04.validate-ccm.sh               # Namespaced issuer (default)
./04.validate-ccm.sh use-cluster-issuer   # Cluster issuer
```

Requests a TLS certificate. The secret is labeled `app=sample1` for use by VirtualServer VS1.
You should see the following output when you validate certificate issuance

```
❯ ./04.validate-ccm.sh
>> Creating venafi-cloud-credentials Secret in cyberark
secret/venafi-cloud-credentials created
>> Creating cross-namespace VenafiConnection in cyberark
venaficonnection.jetstack.io/venafi-saas-connection-cross-ns created
>> Creating cluster-wide VenafiConnection in cyberark
venaficonnection.jetstack.io/venafi-saas-connection-cluster-wide created
>> Applying RBAC so Venafi components can read venafi-cloud-credentials
role.rbac.authorization.k8s.io/read-ccm-credentials created
rolebinding.rbac.authorization.k8s.io/read-ccm-credentials created
>> Ensuring app namespace sandbox
>> Creating VenafiIssuer (namespaced) in sandbox
venafiissuer.jetstack.io/venafi-saas-issuer created
>> Creating VenafiClusterIssuer (cluster-wide)
venaficlusterissuer.jetstack.io/venafi-saas-cluster-issuer created
>> Requesting Certificate nginx-1014571909.svc.cluster.local in sandbox using VenafiIssuer/venafi-saas-issuer (jetstack.io)
certificate.cert-manager.io/nginx-1014571909.svc.cluster.local created
>> Waiting up to 30s for Certificate nginx-1014571909.svc.cluster.local to be Ready...
#################################################
Certificate nginx-1014571909.svc.cluster.local is Ready
Secret: nginx-1014571909.svc.cluster.local (labels: app=sample1, env=dev)
```

Optionally run it again with `./04.validate-ccm.sh use-cluster-issuer` to request another certificate with `VenafiClusterIssuer`

### Step 5 – Create VirtualServers

```bash
./05.create-virtual-server.sh
```

Creates three VirtualServers:
- **vs1-tlssecret** → uses the labeled TLS secret.
- **vs2-issuer** → uses the namespaced issuer inline in the spec.
- **vs3-clusterissuer** → uses the cluster issuer inline in the spec.

Running this should show 

```
❯ ./05.create-virtual-server.sh
>> Validating service echo in namespace sandbox
>> Ensuring namespace sandbox exists
>> Looking up TLS secret with label selector 'app=sample1' in sandbox
>> Creating VirtualServer vs1-tlssecret (host: nginx-3514591909.svc.cluster.local, secret: nginx-1014571909.svc.cluster.local)
virtualserver.k8s.nginx.org/vs1-tlssecret created
>> Creating VirtualServer vs2-issuer (host: issuer-3514591909.svc.cluster.local, issuer: venafi-saas-issuer kind=VenafiIssuer group=jetstack.io)
virtualserver.k8s.nginx.org/vs2-issuer created
>> Creating VirtualServer vs3-clusterissuer (host: cluster-3514591909.svc.cluster.local, cluster-issuer: venafi-saas-cluster-issuer)
virtualserver.k8s.nginx.org/vs3-clusterissuer created
>> Listing VirtualServers in sandbox:
NAME                STATE     HOST                                   IP               EXTERNALHOSTNAME   PORTS      AGE
demo-vs             Valid     nginx-1714501909.svc.cluster.local     xxx.xxx.xxx.xxx                     [80,443]   9m12s
vs1-tlssecret       Valid     nginx-3514591909.svc.cluster.local     xxx.xxx.xxx.xxx                     [80,443]   20s
vs2-issuer          Valid     issuer-3514591909.svc.cluster.local    xxx.xxx.xxx.xxx                     [80,443]   20s
vs3-clusterissuer   Warning   cluster-3514591909.svc.cluster.local   xxx.xxx.xxx.xxx                     [80,443]    0s

>> Done. Test with (LB=xxx.xxx.xxx.xxx):
  VS1_HOST=nginx-3514591909.svc.cluster.local
  VS2_HOST=issuer-3514591909.svc.cluster.local
  VS3_HOST=cluster-3514591909.svc.cluster.local

  # HTTPS tests
  curl -vk --resolve "nginx-3514591909.svc.cluster.local:443:xxx.xxx.xxx.xxx" https://nginx-3514591909.svc.cluster.local/
  curl -vk --resolve "issuer-3514591909.svc.cluster.local:443:xxx.xxx.xxx.xxx" https://issuer-3514591909.svc.cluster.local/
  curl -vk --resolve "cluster-3514591909.svc.cluster.local:443:xxx.xxx.xxx.xxx" https://cluster-3514591909.svc.cluster.local/
```
Wait for a few seconds and run `kubectl get VirtualServer -n sandbox` to see

```
❯ kubectl get VirtualServer -n sandbox
NAME                STATE     HOST                                   IP               PORTS      AGE
demo-vs             Valid     nginx-1714501909.svc.cluster.local     xxx.xxx.xxx.xxx  [80,443]   11m
vs1-tlssecret       Valid     nginx-3514591909.svc.cluster.local     xxx.xxx.xxx.xxx  [80,443]   119s
vs2-issuer          Valid     issuer-3514591909.svc.cluster.local    xxx.xxx.xxx.xxx  [80,443]   119s
vs3-clusterissuer   Warning   cluster-3514591909.svc.cluster.local   xxx.xxx.xxx.xxx  [80,443]   118s
```

Use the commands from HTTPS tests to validate that VirtualServer works as expected with TLS. The `vs3-clusterissuer` will not work as it has issues that needs to be addressed in NGINX Plus.

### Step 6 – Cleanup

```bash
./06.cleanup.sh
```

Deletes all namespaces, issuers, secrets, CRDs, and local artifacts created during the demo.

---

## Notes

- Cert-manager integration is enabled via `controller.enableCertManager=true` in the NGINX Plus Helm chart.
- All scripts source variables from `env-vars.sh` to avoid hardcoding values.
- Certificate issuance requires a valid `CERT_ZONE` and `CCM_APIKEY` associated with your CyberArk environment.

---

## License

This demo requires a valid **NGINX Plus license** and a valid **CyberArk Certificate Manager API key**.
