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
  description = "Environment name used in resource names."
  type        = string
  default     = "dev"
}

variable "base_cidr" {
  description = "Address range that subnets are carved from."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnets" {
  description = "Subnets to create, keyed by short name."
  type = map(object({
    region = string
  }))
}

variable "firewall_rules" {
  description = "Protocols and ports allowed into instances tagged \"web\"."
  type = list(object({
    protocol = string
    ports    = list(string)
  }))
}

variable "enable_ssh" {
  description = "Create a firewall rule that allows SSH through Identity-Aware Proxy."
  type        = bool
  default     = false
}

variable "buckets" {
  description = "Buckets to create, keyed by short name."
  type = map(object({
    location      = string
    storage_class = optional(string, "STANDARD")
  }))
}
