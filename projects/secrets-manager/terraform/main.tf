resource "null_resource" "issue_cert" {
  triggers = {
    always_run = timestamp()  # force rerun each time
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/../issue-cert.sh"
    environment = {
      CSM_TENANT           = var.csm_tenant
      CONJUR_ACCOUNT       = var.conjur_account
      CSM_WORKLOAD_APIKEY  = var.csm_workload_apikey
      CSM_WORKLOAD_ID      = var.csm_workload_id
      CERT_NAME            = var.cert_name
      URI_NAMES            = var.uri_names
      ZONE                 = var.zone
      CERT_DURATION        = var.cert_duration
      ISSUER_NAME          = var.issuer_name
    }
  }
}
