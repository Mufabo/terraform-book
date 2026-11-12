variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west1"
}

variable "environments" {
  description = "Environments to build a network for, with the number of their /24 inside 10.70.0.0/16."
  type        = map(number)
  default = {
    dev  = 0
    test = 1
  }
}
