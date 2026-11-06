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

  # TODO: validation — must be one of dev, staging, prod
}

variable "machine_type" {
  description = "Compute Engine machine type for the web server."
  type        = string
  default     = "e2-micro"

  # TODO: validation — must start with "e2-"
}

variable "allowed_cidr" {
  description = "CIDR range allowed to reach the web server on port 80."
  type        = string

  # TODO: validation — must be a valid CIDR (hint: can(cidrhost(var.allowed_cidr, 0)))
}
