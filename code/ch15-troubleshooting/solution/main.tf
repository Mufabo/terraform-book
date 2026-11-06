resource "random_id" "suffix" {
  byte_length = 3
}

resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "web" {
  name                    = "ch15-network"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "web" {
  name          = "ch15-subnet"
  ip_cidr_range = "10.50.0.0/24"
  region        = var.region
  network       = google_compute_network.web.id
}

locals {
  bucket_purposes = toset(["logs", "assets"])
}

resource "google_storage_bucket" "this" {
  for_each = local.bucket_purposes

  name                        = "ch15-${each.key}-${random_id.suffix.hex}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}
