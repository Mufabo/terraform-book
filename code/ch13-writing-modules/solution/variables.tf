variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Environment name. Exists only in the root module."
  type        = string
  default     = "dev"
}
