provider "google" {
  project = var.project_id
  region  = "europe-west1" # TODO: var.region (after you declare it in variables.tf)
}
