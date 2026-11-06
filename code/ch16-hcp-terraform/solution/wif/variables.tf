variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west1"
}

variable "hcp_organization" {
  description = "Name of your HCP Terraform organization."
  type        = string
}

variable "hcp_workspace" {
  description = "HCP Terraform workspace allowed to impersonate the service account."
  type        = string
  default     = "ch16-app"
}
