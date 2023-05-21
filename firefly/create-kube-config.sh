#!/bin/sh

# FOR 1.24+ Kubernetes clusters ONLY - as secrets are no longer auto-generated with serviceaccount creations
# The script does a few things: creates a serviceaccount, creates a secret for that serviceaccount (and annotates accordingly),
# provides a kubeconfig output to the screen as well as writing to a file that can be included in the KUBECONFIG or PATH

# Feed variables to kubectl commands (modify as needed). 
# ------------------------------------------- #
clustername=${CLUSTER_FULLNAME}
server=${CLUSTER_URL}
name=firefly
ns=cert-manager # namespace
# ------------------------------------------- #

# Check for existing serviceaccount first
sa_precheck=$(kubectl get sa $name -o jsonpath='{.metadata.name}' -n $ns) > /dev/null 2>&1

if [ -z "$sa_precheck" ]
then 
    kubectl create serviceaccount $name -n $ns
else
    echo "serviceacccount/"$sa_precheck" already exists"  
fi

sa_name=$(kubectl get sa $name -o jsonpath='{.metadata.name}' -n $ns)
sa_uid=$(kubectl get sa $name -o jsonpath='{.metadata.uid}' -n $ns)

# Check for existing secret/service-account-token, if one does not exist create one but do not output to external file
secret_precheck=$(kubectl get secret $sa_name-token-$sa_uid -o jsonpath='{.metadata.name}' -n $ns) > /dev/null 2>&1

if [ -z "$secret_precheck" ]
then 
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Secret
    type: kubernetes.io/service-account-token
    metadata:
      name: $sa_name-token-$sa_uid
      namespace: $ns
      annotations:
        kubernetes.io/service-account.name: $sa_name
EOF
else
    echo "secret/"$secret_precheck" already exists"
fi

# Create Kube Config and output to config file
ca=$(kubectl get secret $sa_name-token-$sa_uid -o jsonpath='{.data.ca\.crt}' -n $ns)
token=$(kubectl get secret $sa_name-token-$sa_uid -o jsonpath='{.data.token}' -n $ns | base64 --decode)

echo "
apiVersion: v1
kind: Config
clusters:
  - name: ${clustername}
    cluster:
      certificate-authority-data: ${ca}
      server: ${server}
contexts:
  - name: ${sa_name}@${clustername}
    context:
      cluster: ${clustername}
      namespace: ${ns}
      user: ${sa_name}
users:
  - name: ${sa_name}
    user:
      token: ${token}
current-context: ${sa_name}@${clustername}
" | tee artifacts/kubeconfig.yaml

