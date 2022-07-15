# Instructions to run the Jetstack Isolated issuer

## Assumptions
- You have access to the binary that allows you to the isolated issuer. isolated-issuer is available as a docker image in addtion to a binary that can run on many operating systems. 
- cert-manager is already installed on the cluster

## Instructions
If you prefer to manually execute the commands of the Makefile , you can do so. If you prefer to run the Makefile, first step is to 
`cp settings-template.sh settings.sh`
The file settings.sh sets up the environment variables and loads it in the Makefile

If you are working on Kubernetes, there is nothing to set the environment variables. You can safely ignore values and proceed to look at the section relevant to Kubernetes in the Makefile

### For the platform team operating Kubernetes  
- prep-kubernetes target is for someone who has access to Kubernetes 
   - Running it will create a namespace where we will eventually create certificates 
   - It will also create the required CRD's and RBACS for managing certificate requests from the cluster.
- Addtionally, create a copy of ~/.kube/config as it will be used by isolated issuer from a remote machine to connect to the cluster.
    - cp ~/.kube/config ./kubeconfig-for-isolated-issuer
- If your config has multiple contexts, you can remove the ones that are not required. Simply run,
    - kubectl config --kubeconfig kubeconfig-for-isolated-issuer get-contexts -o name
    And for each context that you don't need, run 
    - kubectl config --kubeconfig kubeconfig-for-isolated-issuer delete-context minikube
- Share kubeconfig-for-isolated-issuer with the security team or transfer it to the machine where isolated issuer will run. Optionally install kubectl to validate that the machine can connect to the cluster. 

### For the security team operating the Venafi platform 

- Review the file tpp-isolated_issuer_config-template.yaml 
- The configuration in the file is pretty straightforward. 
- Make a copy of settings-template.sh to settings.sh 
- Set the environment variables as needed.  
   - zone is the policy folder in Venafi. The CA template configured in this folder must have the ability to create a issuing certificate
   - url is the URL of the Venafi TPP platform
   - accessToken is the token that will allow access to TPP
   - caFile is the chain that needs to be attached to every certificate that will be issued to the cluster. For e.g if you create a certificate from the defined zone, the chain associated with the cert is what is needed here. It needs to be in PEM form

### The Machine
 - Make sure the binary isolated-issuer is available on the machine
 - Make sure kubeconfig-for-isolated-issuer is available in the machine 
 - Make sure tpp-isolataed_issuer_confg.yaml is available in the machine
 
  
