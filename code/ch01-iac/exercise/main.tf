# A small web environment on Google Cloud.
# You do not need to run this file yet — just read it.

terraform {
  required_version = "~> 1.17.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
  }
}

provider "google" {
  project = "tf-book-fatih-12345"
  region  = "europe-west1"
}

resource "google_compute_network" "web" {
  name                    = "dev-web-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "web" {
  name          = "dev-web-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.web.id
}

resource "google_compute_firewall" "allow_http" {
  name    = "dev-allow-http"
  network = google_compute_network.web.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

resource "google_compute_instance" "web" {
  name         = "dev-web-vm"
  machine_type = "e2-micro"
  zone         = "europe-west1-b"
  tags         = ["web"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.web.id
    access_config {}
  }
}
