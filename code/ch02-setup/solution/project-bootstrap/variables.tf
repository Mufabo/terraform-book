variable "project_id" {
  description = "Globally unique project ID, e.g. tf-book-fatih-12345."
  type        = string
}

variable "billing_account" {
  description = "Billing account ID from `gcloud billing accounts list`."
  type        = string
}

variable "budget_amount" {
  description = "Monthly budget, in the billing account's currency."
  type        = number
  default     = 10
}

variable "budget_currency" {
  description = "Currency of the billing account, e.g. USD or EUR."
  type        = string
  default     = "USD"
}

variable "services" {
  description = "APIs to enable in the project (section 2.5)."
  type        = set(string)
  default = [
    "compute.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "secretmanager.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ]
}
