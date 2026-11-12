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
  description = "Teams and the environments each one needs a bucket in."
  type = map(object({
    environments = list(string)
    location     = optional(string, "EU")
  }))
  default = {
    shop    = { environments = ["dev", "prod"] }
    reports = { environments = ["prod"], location = "EUROPE-WEST1" }
  }
}

variable "temporary_days" {
  description = "Objects in non-prod buckets are deleted after this many days."
  type        = number
  default     = 14
}
