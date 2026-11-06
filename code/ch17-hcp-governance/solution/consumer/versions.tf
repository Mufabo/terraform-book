terraform {
  required_version = "~> 1.17.0"

  cloud {
    organization = "tf-book-yourname" # your HCP Terraform organization

    workspaces {
      project = "terraform-book"
      name    = "ch17-consumer"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
  }
}
