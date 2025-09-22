/*
 * Copyright 2022 Venafi, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
/*
Sample script for creating a Intermediate Certificate Authority in Vault. 
Script adopted from https://github.com/venafi/cert-manager-demos/tree/master/istio-csr/install-vault/terraform@MattiasGees
NOT FOR PRODUCTION USE
*/

locals {
  # expects the output of 
  # vault operator init -format=json > myfile-cluster-keys.json
  # to be in file referenced in local.cluster_data
  cluster_data = jsondecode(file("login.json"))
  vault_addr = "http://127.0.0.1:18200"
}

# Provider for the root namespace context
provider "vault" {
  token = local.cluster_data.root_token
  address = local.vault_addr
}

### AT ROOT LEVEL ###

resource "vault_policy" "admin" {
  name = "admin"

  policy = <<EOT
path "*" {
  capabilities = ["create","read","update","delete","list","sudo"]
}
EOT
}

resource "vault_auth_backend" "userpass" {
  type = "userpass"
}

resource "vault_generic_endpoint" "gatesy" {
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/gatesy"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "policies": ["admin"],
  "password": "gatesy"
}
EOT
}

resource "vault_mount" "venafi-demo-pki-root" {
  path        = "venafi-demo-pki-root"
  type        = "pki"
  description = "This is Venafi Cloud Demo Root CA"
  max_lease_ttl_seconds = 315360000
}

resource "vault_pki_secret_backend_root_cert" "venafi-demo-pki-root" {

  backend = vault_mount.venafi-demo-pki-root.path

  type                  = "internal"
  common_name           = "Venafi Cloud Demo Root CA"
  ttl                   = 315360000
  format                = "pem"
  private_key_format    = "der"
  key_type              = "rsa"
  key_bits              = 4096
  exclude_cn_from_sans  = true
  ou                    = "Venafi Cloud"
  organization          = "Venafi Inc."
}

resource "local_file" "ca" {
    content     = "${vault_pki_secret_backend_root_cert.venafi-demo-pki-root.certificate}"
    filename = "ca.pem"
}

# Create PKI engine

resource "vault_mount" "venafi-demo-mesh-ca" {
  path        = "venafi-demo-mesh-ca"
  type        = "pki"
  max_lease_ttl_seconds = 31536000
  description = "Venafi Cloud Demo ICA"
}

resource "vault_pki_secret_backend_role" "venafi-secure-istio-csr" {

  backend = vault_mount.venafi-demo-mesh-ca.path
  name    = "venafi-secure-istio-csr"
  
  allow_any_name                     = true
  allow_glob_domains                 = false
  allow_bare_domains                 = false
  allow_ip_sans                      = true
  allow_localhost                    = true
  allow_subdomains                   = false
  allowed_uri_sans                   = ["*"]
  basic_constraints_valid_for_non_ca = true
  client_flag                        = true
  code_signing_flag                  = false
  email_protection_flag              = false
  enforce_hostnames                  = true
  generate_lease                     = false
  key_bits                           = 2048
  key_type                           = "rsa"
  no_store                           = false
  require_cn                         = false
  server_flag                        = true
  use_csr_common_name                = false
  use_csr_sans                       = true
  ttl                                = 3600
  max_ttl                            = 2592000
  key_usage                          = ["DigitalSignature", "KeyAgreement", "KeyEncipherment" ]

}

resource "vault_pki_secret_backend_intermediate_cert_request" "intermediate" {
  depends_on = [ vault_mount.venafi-demo-mesh-ca ]
  backend = vault_mount.venafi-demo-mesh-ca.path
  type = "internal"
  common_name = "Venafi Cloud Demo ICA"
  ou = "Venafi Cloud"
  organization = "Venafi Inc."
  country = "US"
}

resource "vault_pki_secret_backend_root_sign_intermediate" "root" {
  depends_on = [ vault_pki_secret_backend_intermediate_cert_request.intermediate ]
  backend = "venafi-demo-pki-root"
  csr = vault_pki_secret_backend_intermediate_cert_request.intermediate.csr
  common_name = "Venafi Cloud Demo ICA"
  ou = "Venafi Cloud"
  organization = "Venafi Inc."
  ttl = 157680000
}

data "vault_generic_secret" "root_ca_chain" {
  depends_on = [vault_pki_secret_backend_root_cert.venafi-demo-pki-root]
  path     = "venafi-demo-pki-root/cert/ca"
}

resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate" { 
  backend = vault_mount.venafi-demo-mesh-ca.path
  certificate = <<-EOT
${vault_pki_secret_backend_root_sign_intermediate.root.certificate}
EOT
}

# create pki policy for pki roles

resource "vault_policy" "pki-istio-ca" {
  name = "pki-istio-ca"

  policy = <<EOT
path "venafi-demo-mesh-ca/*" {
  capabilities = ["create","update"]
}
EOT
}
