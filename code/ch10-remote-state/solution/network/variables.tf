variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Region for the subnet."
  type        = string
  default     = "europe-west1"
}
