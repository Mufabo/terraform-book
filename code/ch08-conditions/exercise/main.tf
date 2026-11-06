resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_storage_bucket" "data" {
  name                        = "${var.project_id}-${var.environment}-ch08-data"
  location                    = var.region
  uniform_bucket_level_access = true

  # TODO: protect this bucket with lifecycle { prevent_destroy = true }
}

resource "google_compute_firewall" "allow_http" {
  name    = "${var.environment}-ch08-allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = [var.allowed_cidr]
  target_tags   = ["web"]

  depends_on = [google_project_service.compute]
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"

  # TODO: add a lifecycle postcondition: self.status == "READY"
}

data "google_compute_zones" "available" {
  region = var.region

  depends_on = [google_project_service.compute]
}

resource "google_compute_instance" "web" {
  name         = "ch08-web"
  machine_type = var.machine_type
  zone         = data.google_compute_zones.available.names[0]
  tags         = ["web"]

  labels = {
    environment = var.environment
  }

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
  EOT

  # TODO: add a lifecycle block with
  #   - a precondition: prod must not use e2-micro
  #   - ignore_changes for labels["owner"]
}

# TODO: add a check block "website_is_up" with a scoped data "http" "home"
# that requests the web URL, and an assert that status_code == 200.

output "web_url" {
  value = "http://${google_compute_instance.web.network_interface[0].access_config[0].nat_ip}"
}
