# Instructions to install and configure Jetstack Enterprise policy approver for cert-manager

## Assumptions
- You are a Venafi Jetstack Secure customer and you have access to credentials to access enterprise builds

## Files to review

- The chart values to install Jetstack Enterprise cert-manager is located [here] (cert-manager/values.yaml). Note that cert-manager will be installed with the certificate approver controller disabled. This means that none of the certificates will be automatically approved.
- The chart values to install Jetstack Enterprise policy approver fo cert-manager is located [here] (approver-policy/values.yaml). Additional `approveSignerNames` will need to be added for enterprise / community issuers. For e.g `isolated-issuer`, `aws-pca-issuer`, `google-cas-issuer`, etc. 
- `settings-template.sh`. Make a copy and create `settings.sh` and set values accordingly 
- The `Makefile` itself that has commands to run 

## Install instructions 

- The first step to initialize assumes that you have a token to access Jetstack Enterprise build and the token itself is named `sa-key.json`. If you don't have one, or have named it differently update the `Makefile`
- Simply run `make init` to create the temporary directories, namespaces and configure the namespace with a `docker-registry` secret 
- Run `make install-cert-manager-without-auto-approver` to install cert-manager. The version of cert-manager that will be installed will be looked up from your `settings.sh`
- Run `make install-jetstack-approver-policy-module` to install Jetstack policy approver for cert-manager 
- Validate that all the pods are running in `jetstack-secure` namespace. `cert-manager` and the `approver-policy` is deployed in the `jetstack-secure` namespace. 

## Validating your installation

### Creating an issuer 
- Create a Venafi issuer by simply running `make create-venafi-issuer`. This will create a venafi issuer based on what is defined in `templates\venafi-issuer.yaml`. The values for the issuer will be retrieved from `settings.sh`

### Testing your install
- Now, create a certificate by running `make create-certificate1`. The template for certificate is located at `templates\sample-cert1.yaml`. Make sure that the certificate template is defined in a way that allows certs to be issued by Venafi
- Run `kubectl get certificate <name of your cert> -n sandbox` and the associated `CertificateRequest` resource. You will see 
```
Events:
  Type    Reason       Age   From                    Message
  ----    ------       ----  ----                    -------
  Normal  Unprocessed  11s   policy.cert-manager.io  Request is not applicable for any policy so ignoring
```
- This is expected as there is no policy defined to allow processing this `CertificateRequest`

### Creating a Certificate Request Policy

- Review the file `templates/cert-policy.yaml`. This is the policy that will be applied for CertificateRequests that match the defined issuerRef conditions 
- Run `make create-venafi-tpp-certificate-policy` to create the policy. 
- Check the status of the `CertificateRequestPolicy` by running `kubectl get crp`. The `Ready` state for `cert-policy-for-apps-in-sandbox` should be `True`
- Describe the `CertificateRequestPolicy` by running `kubectl describe crp` and you will see 
```
Events:
  Type    Reason  Age                From                    Message
  ----    ------  ----               ----                    -------
  Normal  Ready   19s (x3 over 80s)  policy.cert-manager.io  CertificateRequestPolicy is ready for approval evaluation
```
- `CertificateRequestPolicy` is a non-namespaced resource. Addtionally you will need to create the relevant RBAC's for the user requesting certificates
- Run `make create-rbac-for-cert-request-policy`. This uses the file in `templates/cert-policy-rbac.yaml` . Currently the RBAC's are defined for all users. You may have multiple policies that map to relevant users in specific namespaces. That may require you to create relvant Role and RoleBindings. This example creates a ClusterRole and a ClusterRoleBinding 
- **NOTE**: The previous certificate request (run via `create-certificate1`) will now be approved if it satisfies all the conditions. 

### Testing the policy 

- Run `make create-certificate2`. The template for this is located at `templates/sample-cert2.yaml`. 
- Validate that the certificate was successfully issued. Both the `Approved` and `Ready` flags will be `true`.
- At this time, you should have 2 `CertificateRequest` resources and both will have it's `Approved` and `Ready` flag set to true.
- Additionally, run `make create-certificate3`. The template for this is located at `templates/sample-cert3.yaml`. The template has an addtional string at the end of DNS and will fail unless the Venafi policy is completely open. 
- Check the `CertificateRequest` resource and you will see `Denied` flag set to `true` and `Ready` flag set to `False`

The policy itself is defined in the Venafi platform. However, the enforcement happens in-cluster allowing security teams to enable local policies. 