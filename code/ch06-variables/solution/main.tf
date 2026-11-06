locals {
  name_prefix = "${var.environment}-${var.network.name}"

  common_labels = merge(var.labels, {
    environment = var.environment
    managed_by  = "terraform"
  })
}

resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_storage_bucket" "assets" {
  name                        = "${var.project_id}-${local.name_prefix}-assets"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  labels                      = local.common_labels
}

resource "google_compute_network" "main" {
  name                    = "${local.name_prefix}-network"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "main" {
  name          = "${local.name_prefix}-subnet"
  ip_cidr_range = var.network.subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id
}

resource "google_compute_firewall" "allow_web" {
  name    = "${local.name_prefix}-allow-web"
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
    ports    = var.network.allowed_ports
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}
