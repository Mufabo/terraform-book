variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west1"
}

variable "bucket_location" {
  description = "Location of the sample bucket. Try US to see a violation."
  type        = string
  default     = "EU"
}

variable "public_service" {
  description = "Allow unauthenticated access to the Cloud Run service."
  type        = bool
  default     = false
}
