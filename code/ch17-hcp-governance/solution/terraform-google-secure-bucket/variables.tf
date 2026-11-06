variable "project_id" {
  description = "Project in which to create the bucket."
  type        = string
}

variable "name" {
  description = "Globally unique bucket name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", var.name))
    error_message = "Bucket names must be 3-63 characters of lowercase letters, digits, dots, hyphens, or underscores."
  }
}

variable "location" {
  description = "Bucket location, e.g. EU or europe-west1."
  type        = string
  default     = "EU"
}

variable "retention_days" {
  description = "Delete objects older than this many days. 0 disables the rule."
  type        = number
  default     = 0
}

variable "readers" {
  description = "IAM members granted read access, e.g. user:ana@example.com."
  type        = set(string)
  default     = []
}

variable "labels" {
  description = "Labels added to the bucket."
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Allow deleting the bucket even if it contains objects."
  type        = bool
  default     = false
}
