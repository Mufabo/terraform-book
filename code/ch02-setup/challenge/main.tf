# Chapter 2 challenge: read three facts about your setup and create nothing.

provider "google" {
  project = "tf-book-fatih-12345" # your project ID
  region  = "europe-west1"
}

# The identity Terraform is authenticated as (your ADC login).
data "google_client_openid_userinfo" "me" {}

# The project and region the provider is configured with.
data "google_client_config" "current" {}

# The zones of the provider's region. Needs the Compute Engine API (2.5).
data "google_compute_zones" "available" {}

output "terraform_identity" {
  value = data.google_client_openid_userinfo.me.email
}

output "default_region" {
  value = data.google_client_config.current.region
}

output "zones" {
  value = data.google_compute_zones.available.names
}
