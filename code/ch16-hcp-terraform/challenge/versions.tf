terraform {
  required_version = "~> 1.17.0"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "0.82.0"
    }
  }
}
