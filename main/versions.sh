# Versions based on output of 
# venctl components kubernetes manifest print-versions
export approver-policy-enterprise :="v0.17.0"
export aws-privateca-issuer :="v1.2.7"
export cert-manager :="v1.14.5"
export cert-manager-approver-policy :="v0.14.1"
export cert-manager-csi-driver :="v0.8.1"
export cert-manager-csi-driver-spiffe :="v0.6.0"
export firefly :="v1.3.4"
export trust-manager :="v0.10.0"
export venafi-connection :="v0.1.0"
export venafi-enhanced-issuer :="v0.14.0"
export venafi-kubernetes-agent :="0.1.48"

# Used for installing istio-csr as it is not part of VMG at this time
export VEN_CONTAINER_REGISTRY :=private-registry.venafi.cloud
export VEN_ISTIO_CSR_VERSION :="v0.8.1"
export VEN_DOCKER_REGISTRY_SECRET :=venafi-image-pull-secret
