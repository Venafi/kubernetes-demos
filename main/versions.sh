# Versions based on output of 
# venctl components kubernetes manifest print-versions
export approver-policy-enterprise :="v0.18.0"
export aws-privateca-issuer :="v1.3.0"
export cert-manager :="v1.15.2"
export cert-manager-approver-policy :="v0.15.0"
export cert-manager-csi-driver :="v0.10.0"
export cert-manager-csi-driver-spiffe :="v0.8.0"
export firefly :="v1.4.2"
export trust-manager :="v0.12.0"
export venafi-connection :="v0.1.0"
export venafi-enhanced-issuer :="v0.14.0"
export venafi-kubernetes-agent :="0.1.49"

# Used for installing istio-csr as it is not part of VMG at this time
export VEN_CONTAINER_REGISTRY :=private-registry.venafi.cloud
export VEN_ISTIO_CSR_VERSION :="v0.10.0"
export VEN_DOCKER_REGISTRY_SECRET :=venafi-image-pull-secret
