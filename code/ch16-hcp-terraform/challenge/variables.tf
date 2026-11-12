variable "organization" {
  description = "Your HCP Terraform organisation."
  type        = string
}

variable "project_id" {
  description = "Google Cloud project the workspaces deploy to."
  type        = string
}

variable "service_account_email" {
  description = "Service account the runs impersonate (output of wif/)."
  type        = string
}

variable "workload_provider_name" {
  description = "Full name of the workload identity pool provider (output of wif/)."
  type        = string
}
