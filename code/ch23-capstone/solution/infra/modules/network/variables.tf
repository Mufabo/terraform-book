variable "project_id" {
  description = "Project in which to create the network."
  type        = string
}

variable "region" {
  description = "Region of the subnet."
  type        = string
}

variable "name" {
  description = "Name prefix for the network resources, e.g. dev-web-shop."
  type        = string
}

variable "subnet_cidr" {
  description = "Primary IPv4 range of the subnet."
  type        = string

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid CIDR block, e.g. 10.10.0.0/24."
  }
}
