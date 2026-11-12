resource "google_compute_network" "legacy" {
  name                    = "ch11c-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "legacy" {
  name          = "ch11c-subnet"
  region        = "europe-west1"
  ip_cidr_range = "10.60.0.0/24"
  network       = google_compute_network.legacy.id
}

# Step 3 of the challenge renamed this resource from "allow_ssh" to "iap_ssh".
moved {
  from = google_compute_firewall.allow_ssh
  to   = google_compute_firewall.iap_ssh
}

resource "google_compute_firewall" "iap_ssh" {
  name    = "ch11c-allow-ssh-iap"
  network = google_compute_network.legacy.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
}
