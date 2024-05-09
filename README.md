# Getting started with Venafi Control Plane

## Assumptions
- You have access to Venafi Control Plane and have the entitlements to use **Firefly** and **TLS Protect For Kubernetes**
- If you do not, sign up for an account at https://ui.venafi.cloud and reach out to us. 

## Self paced walkthroughs

### Full installation 
Change to `main` directory and follow the [documentation](main/README.md)

### Installing the Venafi Kubernetes discovery component in cluster
To install only the Venafi Kubernetes discovery component in your cluster, follow the instructions written [here](projects/cert-discovery/README.md)

### Installing the Venafi Kuberentes components in cluster with an existing cert-manager installation
To install Venafi components without cert-manager (assumes you have a functional cert-manager in cluster), follow the instructions written [here](projects/ven03/README.md)

### Condensed usecases
Change to `projects` directory and you will find different folders with specific README. 


**NOTE** This repo is for demos only.  