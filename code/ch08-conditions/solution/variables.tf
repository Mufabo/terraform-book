variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Region for regional resources."
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "machine_type" {
  description = "Compute Engine machine type for the web server."
  type        = string
  default     = "e2-micro"

  validation {
    condition     = startswith(var.machine_type, "e2-")
    error_message = "Only cost-efficient e2- machine types are allowed in this course."
  }
}

variable "allowed_cidr" {
  description = "CIDR range allowed to reach the web server on port 80."
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0))
    error_message = "allowed_cidr must be a valid CIDR block, for example 203.0.113.0/24."
  }
}
