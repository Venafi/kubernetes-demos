variable "csm_tenant" {
  type        = string
  description = "Cyberark Secrets Manager tenant name"
}

variable "conjur_account" {
  default = "conjur"
}

variable "csm_workload_id" {
  type        = string
  description = "Workload Identifier in Cyberark Secrets Manager"
}

#api key is one way to connect to CSM. Use JWT for robust workflows
variable "csm_workload_apikey" {
  type        = string
  description = "Workload API key"
#  sensitive   = true
}

variable "issuer_name" {
  type        = string
  description = "Issuer configured in Cyberark Secrets Manager"
}

variable "cert_name" {
  type        = string
  description = "Common name for the certificate"
}

variable "uri_names" {
  description = "Space-separated URI SANs"
  type        = string
}

variable "cert_duration" {
  type        = string
  description = "Duration of the certificate (e.g., P10D)"
}

variable "zone" {
  description = "Certificate Manager zone"
  type        = string
}
