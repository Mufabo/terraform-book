variable "project_id" {
  description = "Google Cloud project ID (set as a workspace variable)."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west1"
}
