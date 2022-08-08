# Instructions to run the Jetstack Enterprise cert-manager

## Assumptions
- You are a Venafi Jetstack Secure customer and you have access to credentials to access enterprise builds

## Files to review

- The chart values to install Enterprise cert-manager is located [here] (cert-manager/values.yaml)
- The currently configuration is extremely mininal. Just has configuration for a image pull secret and the location of the image.
- settings-template.sh . Make a copy and create settings.sh and set values accordingly 
- The Makefile itself that has commands to run

## Install instructions

- Make a copy of settings-template.sh and create settings.sh if your preferred method to install and configure is Makefile. Alternatively review the Makefile and adapt it as you see fit.
- Run `make init` to create `jetstack-secure` namespace and configure the `docker-registry-secret`. Always review targets before you run. The file referred in the command `sa-key.json` does not exist in the repo. Enterprise customers have access to the secret.
- Run `install-cert-manager` to install cert-manager. Once installation is complete validate that the pods are in Running and Ready state in the `jetstack-secure` namespace. 

## Testing the install
- Simply run `make create-cert` to create a certificate in the `sandbox` namespace. 
- Validate that the certificate's status is `True`. The test certificate is created with a self-signed issuer. Create new issuers as needed and create certificates and put them to use. 

## Cleanup 
- Run `make clean` to remove certs, issuers and cert-manager.
