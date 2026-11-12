locals {
  data_bucket_name = "${var.project_id}-ch15c-data"
}

resource "google_storage_bucket" "this" {
  for_each = toset(var.bucket_names) # bug 1: for_each needs a set or a map

  name                        = "${var.project_id}-ch15c-${each.key}"
  location                    = "EU"
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_storage_bucket" "data" {
  name                        = local.data_bucket_name
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
    logs_for = local.data_bucket_name # bug 2: no reference back to the data bucket
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
  ip_cidr_range = "10.90.1.0/24" # bug 4: no longer inside the app subnet's range
  network       = google_compute_network.main.id
}

output "primary_zone" {
  value = "${var.region}-${var.zones[0]}" # bug 3: indexes start at 0
}
