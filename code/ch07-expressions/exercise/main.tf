locals {
  # A stable, sorted list of subnet names gives each subnet a fixed index.
  subnet_names = sort(keys(var.subnets))

  # TODO: build a map from subnet name to cidrsubnet(var.base_cidr, 8, <index>)
  # Hint: for i, name in local.subnet_names : name => ...
  subnet_cidrs = {}

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

# TODO: google_compute_subnetwork "this" with for_each = var.subnets
#   name          = "<environment>-<key>"
#   region        = each.value.region
#   ip_cidr_range = local.subnet_cidrs[each.key]

resource "google_compute_firewall" "ingress" {
  name    = "${var.environment}-ch07-ingress"
  network = google_compute_network.main.id

  # TODO: replace this static block with a dynamic "allow" block over var.firewall_rules
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

# TODO: google_compute_firewall "ssh" that only exists when var.enable_ssh is true.
#   allow tcp 22 from 35.235.240.0/20 (Identity-Aware Proxy)

# TODO: google_storage_bucket "this" with for_each = var.buckets
#   name = "<project_id>-<environment>-<key>", location and storage_class from each.value
