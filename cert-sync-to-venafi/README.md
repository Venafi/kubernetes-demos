# Pushing certificates to Venafi Trust Protection Platform from Kubernetes


## Assumptions
- You have access to Venafi Jetstack enterprise builds 
- You have information to configure access to the Venafi platform. This includes
  - The URL of the Venafi Trust Protection Platform
  - The policy folder where dicovered certificates need to be placed
  - The access_token with scopes to manage,discover certificates
- If you plan to use the Makefile, you have made a copy of `settings-template.sh` and called it `settings.sh`
- `settings.sh` is updated and represents correct values. 

## Files to review

- The helm chart for the installation is located at cert-sync-to-venafi/cert-sync/values.yaml. This file contains the configuration required to connect to Venafi TPP (although commented to drive the values from Makefile via variables)
- Also review Makefile as you run the various targets

## Installation

- Run the target `prep-kubernetes` . This will create the namespaces `jetstack-secure` and `sandbox` if it doesn't already exist
- Review and run the target `configure-namespace`. This will create the docker registry secret to allow images to be pulled from Venafi Jetstack Enterprise repository
- Run `create-venafi-tpp-access-secret` to create a token that holds `access_token` to connect to Venafi TPP
- Review and run `make install-certificate-sync-module` 

## Validation 

- Check the status of the deployment `kubectl get pods -n jetstack-secure` . The cert-sync pods should be deployed and running 
- If you have access to the Venafi Platform the policy folder configured in the cert-sync module will have certificates discovered.

## Testing 

Testing uses target `create-tls-secrets`. Review it as it will run openssl to generate certificates. If you don't have openssl on your machine you cannot test it locally. 

- Run `make remove-tls-secrets` to clean up 
- Run `make create-tls-secrets` and review them in the Venafi policy folder that was configured to place the certificates 

## Uninstall

- To uninstall cert-sync module, simply run `make remove-certificate-sync-module` 