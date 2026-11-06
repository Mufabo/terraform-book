terraform {
  required_version = "~> 1.17.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
  }
}

variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

provider "google" {
  project = var.project_id
  region  = "europe-west1"
}

locals {
  env = terraform.workspace

  storage_class = {
    dev  = "STANDARD"
    prod = "STANDARD"
  }
}

resource "google_storage_bucket" "demo" {
  name                        = "${var.project_id}-${local.env}-ws-demo"
  location                    = "europe-west1"
  storage_class               = lookup(local.storage_class, local.env, "STANDARD")
  uniform_bucket_level_access = true
  force_destroy               = true

  labels = {
    workspace = local.env
  }
}

output "bucket" {
  value = google_storage_bucket.demo.name
}
