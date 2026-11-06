terraform {
  required_version = "~> 1.17.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.6.3"
    }
  }
}
