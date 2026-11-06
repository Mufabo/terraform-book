# TODO: add a locals block with
#   name_prefix   = "<environment>-<network name>"
#   common_labels = merge(var.labels, { environment = ..., managed_by = "terraform" })

resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_storage_bucket" "assets" {
  name                        = "my-project-dev-web-assets" # TODO: "${var.project_id}-${local.name_prefix}-assets"
  location                    = "europe-west1"              # TODO: var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  # TODO: labels = local.common_labels
}

resource "google_compute_network" "main" {
  name                    = "dev-web-network" # TODO: use local.name_prefix
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "main" {
  name          = "dev-web-subnet" # TODO: use local.name_prefix
  ip_cidr_range = "10.20.0.0/24"   # TODO: var.network.subnet_cidr
  region        = "europe-west1"   # TODO: var.region
  network       = google_compute_network.main.id
}

resource "google_compute_firewall" "allow_web" {
  name    = "dev-web-allow-web" # TODO: use local.name_prefix
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
    ports    = ["80"] # TODO: var.network.allowed_ports
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}
