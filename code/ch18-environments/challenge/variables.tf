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
  description = "Environment this run deploys. Set in <env>.tfvars."
  type        = string
}

variable "min_instances" {
  description = "Minimum number of Cloud Run instances."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances."
  type        = number
  default     = 2
}

variable "deletion_protection" {
  description = "Protect the service and the bucket from deletion."
  type        = bool
  default     = false
}
