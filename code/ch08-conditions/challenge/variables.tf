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
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Bucket location. Data must stay in the EU."
  type        = string
  default     = "EU"

  validation {
    condition     = contains(["EU", "EUROPE-WEST1", "EUROPE-WEST4"], upper(var.location))
    error_message = "location must be EU, EUROPE-WEST1, or EUROPE-WEST4 (upper or lower case)."
  }
}

variable "retention_days" {
  description = "Delete objects after this many days."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_days >= 1 && var.retention_days <= 365
    error_message = "retention_days must be between 1 and 365."
  }

  validation {
    condition     = floor(var.retention_days) == var.retention_days
    error_message = "retention_days must be a whole number."
  }
}

variable "versioning" {
  description = "Keep old versions of objects."
  type        = bool
  default     = false
}
