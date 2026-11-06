variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west1"
}

variable "demo_token" {
  description = "A demo secret value used to practise sensitive outputs."
  type        = string
  sensitive   = true
  default     = "not-a-real-token"
}
