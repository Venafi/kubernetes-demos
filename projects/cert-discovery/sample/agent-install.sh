kubectl create namespace venafi

kubectl apply --namespace=venafi -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: agent-credentials
  namespace: venafi
type: Opaque
stringData:
  privatekey.pem: ""

EOF

helm upgrade venafi-kubernetes-agent oci://registry.venafi.cloud/charts/venafi-kubernetes-agent \
	-f helm/venafi-agent.yaml \
	--install \
	--namespace "venafi" 
