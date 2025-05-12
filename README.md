# Getting started with CyberArk Certificate Manager

## Assumptions
- You have access to CyberArk Certificate Manager and have the entitlements to use **Workload Identity Manager** and **Kubernetes add-on**
- If you do not, sign up for an account at https://ui.venafi.cloud . 

## Self paced walkthroughs

### Full installation - all capabilities with Istio
Change to `main` directory and follow the [documentation](main/README.md)

### CyberArk Certificate Manager and AWS PCA 
To install CyberArk Certificate Manager and use it with AWS PCA , follow the instructions written [here](projects/awspca/README.md)

### CyberArk Certificate Manager Self Hosted
To use CyberArk Certificate Manager Self-Hosted in your cluster , follow the instructions written [here](projects/ven02/README.md)

### Installing the Venafi Kuberentes components in cluster with an existing cert-manager installation
To install Venafi components without cert-manager (assumes you have a functional cert-manager in cluster), follow the instructions written [here](projects/ven03/README.md)

### CyberArk Certificate Manager SaaS
For a simple usecase of using CyberArk Certificate Manager SaaS for your cluster , follow the instructions written [here](projects/ven04/README.md)

### Installing the Venafi Kubernetes discovery component in cluster
To install only the Venafi Kubernetes discovery component in your cluster, follow the instructions written [here](projects/cert-discovery/README.md)

### CyberArk Certificate Manager SaaS with Kong Mesh
For using CyberArk Certificate Manager SaaS with Workload Identity Manager for Kong Mesh , follow the instructions written [here](projects/kong-mesh/README.md)

### Condensed usecases
Change to `projects` directory and you will find different folders with specific README. 


**NOTE** This repo is for demos only.  