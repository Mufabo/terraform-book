resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "web" {
  name                    = "ch05-network"
  auto_create_subnetworks = false

  # The API must be enabled first, but nothing here references it.
  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "web" {
  name          = "ch05-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.web.id
}

resource "google_compute_firewall" "allow_http" {
  name    = "ch05-allow-http"
  network = google_compute_network.web.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

data "google_compute_zones" "available" {
  region = "europe-west1"

  depends_on = [google_project_service.compute]
}

resource "google_compute_instance" "web" {
  name         = "ch05-web"
  machine_type = "e2-micro"
  zone         = data.google_compute_zones.available.names[0]
  tags         = ["web"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
    }
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.web.id
    access_config {} # gives the VM a public IP address
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "<h1>Hello from Terraform</h1>" > /var/www/html/index.html
  EOT
}

output "web_url" {
  value = "http://${google_compute_instance.web.network_interface[0].access_config[0].nat_ip}"
}
