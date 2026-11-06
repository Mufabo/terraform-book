terraform {
  required_version = "~> 1.17.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
  }

  # TODO: add an empty gcs backend block here. The settings come from backend.hcl.
}
