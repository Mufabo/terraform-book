variable "network_id" {
  description = "ID of the VPC network the rule applies to."
  type        = string
}

variable "name" {
  description = "Prefix for the firewall rule name and the network tag."
  type        = string
}
