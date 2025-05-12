helm repo add external-secrets https://charts.external-secrets.io

helm install external-secrets \
	 external-secrets/external-secrets \
	 -n external-secrets \
	 --create-namespace \
	 --set installCRDs=true \
     --wait 

kubectl create namespace cyberark 

# Create conjur credentials
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: conjur-cloud-credentials
  namespace: cyberark
stringData:
  workload-id: host/data/cloud-mis-ztpki-trust-anchor
  apikey: ${CYBR_CONJUR_WORKLOAD_APIKEY}
EOF


# Create conjur secrets provider
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: conjur-cloud-provider
  namespace: cyberark
spec:
  provider:
    conjur:
      url: https://pineapple.secretsmgr.cyberark.cloud/api
      auth:
        apikey:
          account: conjur
          userRef:
            name: conjur-cloud-credentials
            key: workload-id
          apiKeyRef:
            name: conjur-cloud-credentials
            key: apikey
EOF

# Create conjur secret sync with ESO

kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: venafi-ztpki-trust-anchor
  namespace: cyberark
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: conjur-cloud-provider
    kind: SecretStore
  data:
  - secretKey: root-cert.pem
    remoteRef:
      key: data/vault/ski-venafi-trust-anchor-safe/cloud-mis-ztpki-trust-anchor/password
EOF