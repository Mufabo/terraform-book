variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Default region for regional resources."
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Deployment environment name, e.g. dev or prod."
  type        = string
  default     = "dev"
}

variable "labels" {
  description = "Extra labels applied to all resources."
  type        = map(string)
  default     = {}
}

variable "network" {
  description = "Network settings."
  type = object({
    name          = string
    subnet_cidr   = string
    allowed_ports = optional(list(string), ["80"])
  })
}
