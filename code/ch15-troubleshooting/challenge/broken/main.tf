# This configuration has four bugs. Find and fix them; no hints this time.

resource "google_storage_bucket" "this" {
  for_each = var.bucket_names

  name                        = "${var.project_id}-ch15c-${each.key}"
  location                    = "EU"
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_storage_bucket" "data" {
  name                        = "${var.project_id}-ch15c-data"
  location                    = "EU"
  uniform_bucket_level_access = true
  force_destroy               = true

  logging {
    log_bucket = google_storage_bucket.logs.name
  }
}

resource "google_storage_bucket" "logs" {
  name                        = "${var.project_id}-ch15c-logs"
  location                    = "EU"
  uniform_bucket_level_access = true
  force_destroy               = true

  labels = {
    logs_for = google_storage_bucket.data.name
  }
}

resource "google_compute_network" "main" {
  name                    = "ch15c-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "app" {
  name          = "ch15c-app"
  region        = var.region
  ip_cidr_range = "10.90.0.0/24"
  network       = google_compute_network.main.id
}

resource "google_compute_subnetwork" "db" {
  name          = "ch15c-db"
  region        = var.region
  ip_cidr_range = "10.90.0.128/25"
  network       = google_compute_network.main.id
}

output "primary_zone" {
  value = "${var.region}-${var.zones[3]}"
}
