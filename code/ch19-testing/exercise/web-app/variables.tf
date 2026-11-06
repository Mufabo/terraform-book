variable "project_id" {
  description = "Project to deploy into."
  type        = string
}

variable "region" {
  description = "Region for the Cloud Run service and bucket."
  type        = string
}

variable "environment" {
  description = "Environment name: dev, staging, or prod."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "app_name" {
  description = "Short application name used in resource names."
  type        = string
  default     = "web-shop"
}

variable "image" {
  description = "Container image to run."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "min_instances" {
  description = "Minimum number of Cloud Run instances (0 scales to zero)."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances."
  type        = number
  default     = 2

  validation {
    condition     = var.max_instances >= 1 && var.max_instances <= 20
    error_message = "max_instances must be between 1 and 20."
  }
}

variable "public" {
  description = "Allow unauthenticated access to the service."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Protect the Cloud Run service from deletion."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Extra labels for all resources."
  type        = map(string)
  default     = {}
}
