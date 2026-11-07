variable "project_id" {
  description = "Google Cloud project that the pipeline deploys into."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west1"
}

variable "github_repository" {
  description = "GitHub repository allowed to deploy, as OWNER/NAME."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like OWNER/NAME."
  }
}

variable "state_bucket" {
  description = "Existing Terraform state bucket (from Chapter 10)."
  type        = string
}

variable "environments" {
  description = "Environments that get their own apply service account."
  type        = set(string)
  default     = ["dev", "prod"]
}
