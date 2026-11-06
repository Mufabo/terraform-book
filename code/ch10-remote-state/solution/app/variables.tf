variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Region for the subnet."
  type        = string
  default     = "europe-west1"
}

variable "state_bucket" {
  description = "Bucket that holds the network configuration's state."
  type        = string
}
