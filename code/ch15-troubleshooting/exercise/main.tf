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
  region        = "europe-west99"
  network       = google_compute_network.webb.id
}

resource "google_storage_bucket" "this" {
  for_each = toset(["logs-${random_id.suffix.hex}", "assets-${random_id.suffix.hex}"])

  name                        = "ch15-${each.key}"
  locaton                     = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
