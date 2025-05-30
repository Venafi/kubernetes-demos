curr_date=$(date +%S%H%M%d%m)
echo Creating cluster mis-demo-cluster-$curr_date

cat <<EOF | kind create cluster --name mis-demo-cluster-$curr_date --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  extraMounts:
  - hostPath: cyberarkCA.pem
    containerPath: /etc/ssl/certs/cyberarkCA.pem
EOF