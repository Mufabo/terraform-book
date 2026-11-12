# Declarative version of the gcloud script in the Chapter 1 challenge.
# (The terraform and provider blocks are explained in Chapters 3 and 4.)

provider "google" {
  project = "tf-book-fatih-12345"
  region  = "europe-west1"
}

resource "google_storage_bucket" "share" {
  name     = "tf-book-fatih-12345-share"
  location = "EU"
}

resource "google_compute_network" "share" {
  name                    = "share-net"
  auto_create_subnetworks = false
}

resource "google_compute_firewall" "allow_https" {
  name    = "share-allow-https"
  network = google_compute_network.share.id

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["10.0.0.0/8"]
}
