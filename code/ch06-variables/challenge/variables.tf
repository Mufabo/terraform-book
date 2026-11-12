variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west1"
}

variable "team" {
  description = "Team that owns the bucket."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "labels" {
  description = "Extra labels for the bucket."
  type        = map(string)
  default     = {}
}

variable "bucket" {
  description = "Settings of the team bucket."
  type = object({
    location         = string
    storage_class    = optional(string, "STANDARD")
    versioning       = optional(bool, false)
    soft_delete_days = optional(number, 7)
  })
}
