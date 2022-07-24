###########################
# Venafi Specific Variables
###########################


# Venafi TPP access token. You must have the Venafi platform up and running
export JS_VENAFI_TPP_ACCESS_TOKEN :=REPLACE-ME

export JS_VENAFI_TPP_URL :=REPLACE-ME # E.g. https://tpp.mydomain.com/vedsdk

export JS_VENAFI_TPP_BASE64_ENCODED_CACERT :=REPLACE_ME

export JS_VENAFI_TPP_ZONE_PUBLIC_CA1 := REPLACE-ME # E.g. Certificates\\Kubernetes\\Public1
export JS_VENAFI_TPP_ZONE_PUBLIC_CA2 := REPLACE-ME # E.g. Certificates\\Kubernetes\\Public2

export JS_VENAFI_TPP_ZONE_PRIVATE_CA1 := REPLACE-ME # E.g. Certificates\\Kubernetes\\Private1
export JS_VENAFI_TPP_ZONE_PRIVATE_CA2 := REPLACE-ME # E.g. Certificates\\Kubernetes\\Private2

#Location to sync certificates between Kubernetes and Venafi TPP
export JS_VENAFI_CERT_SYNC_POLICY_FOLDER := REPLACE-ME # E.g. Certificates\\Kubernetes\\Discovered

# Venafi API Key. Register for an account on ui.venafi.cloud for a key.
export JS_VENAFI_CLOUD_API_KEY :=REPLACE-ME

# Due to escaping \\ becomes one \, so Demo\\\\demo becomes Demo\\demo
export JS_VENAFI_CLOUD_PUBLIC_ZONE_ID1 :=Demo\\\\demo
export JS_VENAFI_CLOUD_PUBLIC_ZONE_ID2 :=Demo\\\\demo

# Venafi Zone ID for CSI driver specific usecases.
# Due to escaping \\ becomes one \, so Demo\\\\demo becomes Demo\\demo
export JS_VENAFI_CLOUD_PRIVATE_ZONE_ID1 :=Demo\\\\demo
export JS_VENAFI_CLOUD_PRIVATE_ZONE_ID2 :=Demo\\\\demo

export JS_VENAFI_TPP_USERNAME := REPLACE-ME # E.g. user1
export JS_VENAFI_TPP_PASSWORD := REPLACE-ME # E.g. userpass

export JS_VENAFI_PEM_ENCODED_CA_CHAIN_FILE_FOR_ISOLATED_ISSUER :=REPLACE_ME

export JS_DOCKER_EMAIL :=REPLACE_ME

#Component versions
# cert-manager
export JS_CERT_MANAGER_VERSION :=v1.9.0
# cert-discovery-venafi
export JS_VENAFI_CERT_SYNC_VERSION :=v0.1.0
