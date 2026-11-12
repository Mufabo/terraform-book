variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west1"
}

variable "partner_token" {
  description = "API token issued by a partner. Never stored by Terraform."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "partner_token_version" {
  description = "Increase this number whenever partner_token changes."
  type        = number
  default     = 1
}
