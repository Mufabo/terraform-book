variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west1"
}

variable "teams" {
  description = "Teams that get a bucket."
  type        = set(string)
  default     = ["shop", "reports"]
}
