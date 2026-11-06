locals {
  # A stable, sorted list of subnet names gives each subnet a fixed index.
  subnet_names = sort(keys(var.subnets))

  subnet_cidrs = {
    for i, name in local.subnet_names : name => cidrsubnet(var.base_cidr, 8, i)
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "main" {
  name                    = "${var.environment}-ch07-network"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "this" {
  for_each = var.subnets

  name          = "${var.environment}-${each.key}"
  region        = each.value.region
  ip_cidr_range = local.subnet_cidrs[each.key]
  network       = google_compute_network.main.id
}

resource "google_compute_firewall" "ingress" {
  name    = "${var.environment}-ch07-ingress"
  network = google_compute_network.main.id

  dynamic "allow" {
    for_each = var.firewall_rules
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

resource "google_compute_firewall" "ssh" {
  count = var.enable_ssh ? 1 : 0

  name    = "${var.environment}-ch07-ssh-iap"
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Google's Identity-Aware Proxy range.
  source_ranges = ["35.235.240.0/20"]
}

resource "google_storage_bucket" "this" {
  for_each = var.buckets

  name                        = "${var.project_id}-${var.environment}-${each.key}"
  location                    = each.value.location
  storage_class               = each.value.storage_class
  uniform_bucket_level_access = true
  force_destroy               = true
  labels                      = local.labels
}
