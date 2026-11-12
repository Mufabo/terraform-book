variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west1"
}

variable "bucket_names" {
  description = "Short names of the buckets to create."
  type        = list(string)
  default     = ["assets", "exports"]
}

variable "zones" {
  description = "Zone letters available in the region."
  type        = list(string)
  default     = ["b", "c", "d"]
}
