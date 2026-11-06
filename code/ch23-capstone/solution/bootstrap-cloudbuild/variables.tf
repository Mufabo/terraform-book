variable "project_id" {
  description = "Google Cloud project that Cloud Build deploys into."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west1"
}

variable "github_owner" {
  description = "GitHub user or organisation that owns the repository."
  type        = string
}

variable "github_repository" {
  description = "Name of the GitHub repository (without the owner)."
  type        = string
}

variable "state_bucket" {
  description = "Existing Terraform state bucket (from Chapter 10)."
  type        = string
}

variable "environments" {
  description = "Environments that get triggers and an apply service account."
  type        = set(string)
  default     = ["dev", "prod"]
}

variable "approval_environments" {
  description = "Environments whose apply builds need a manual approval."
  type        = set(string)
  default     = ["prod"]
}
