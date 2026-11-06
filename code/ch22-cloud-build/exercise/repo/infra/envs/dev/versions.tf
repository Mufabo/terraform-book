terraform {
  required_version = "~> 1.17.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
  }

  # The bucket is supplied at init time: terraform init -backend-config=backend.hcl
  backend "gcs" {
    prefix = "envs/dev"
  }
}
