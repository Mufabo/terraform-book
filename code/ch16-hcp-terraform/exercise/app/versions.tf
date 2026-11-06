terraform {
  required_version = "~> 1.17.0"

  # TODO: add a cloud block with your organization, project "terraform-book",
  # and workspace "ch16-app".

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
  }
}
