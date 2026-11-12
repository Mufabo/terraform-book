variable "project_id" {
  description = "Project in which to create the network."
  type        = string
}

variable "name" {
  description = "Network name; also the prefix of subnet and firewall rule names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,40}[a-z0-9]$", var.name))
    error_message = "name must be 2-42 characters: lowercase letters, digits, and hyphens, starting with a letter."
  }
}

variable "subnets" {
  description = "Subnets to create, keyed by short name."
  type = map(object({
    region = string
    cidr   = string
  }))

  validation {
    condition     = alltrue([for s in values(var.subnets) : can(cidrhost(s.cidr, 0))])
    error_message = "Every subnet's cidr must be a valid CIDR block, e.g. 10.0.0.0/24."
  }
}

variable "enable_iap_ssh" {
  description = "Allow SSH through Identity-Aware Proxy to VMs with the tag in the ssh_tag output."
  type        = bool
  default     = false
}
