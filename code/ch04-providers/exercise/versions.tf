terraform {
  required_version = "~> 1.17.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
    # TODO: add google-beta (source hashicorp/google-beta, version 8.9.0)
    # TODO: add random (source hashicorp/random, version 3.9.1)
  }
}
