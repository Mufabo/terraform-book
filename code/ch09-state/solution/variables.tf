variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Region for the buckets."
  type        = string
  default     = "europe-west1"
}

variable "buckets" {
  description = "Extra buckets to create, keyed by short name."
  type        = set(string)
  default     = ["logs"]
}
