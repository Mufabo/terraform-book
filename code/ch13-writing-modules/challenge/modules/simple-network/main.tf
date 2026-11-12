resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = var.name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "this" {
  for_each = var.subnets

  project                  = var.project_id
  name                     = "${var.name}-${each.key}"
  region                   = each.value.region
  ip_cidr_range            = each.value.cidr
  network                  = google_compute_network.this.id
  private_ip_google_access = true
}

# Secure by default: the SSH rule is an explicit opt-in.
resource "google_compute_firewall" "iap_ssh" {
  count = var.enable_iap_ssh ? 1 : 0

  project = var.project_id
  name    = "${var.name}-allow-iap-ssh"
  network = google_compute_network.this.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.name}-ssh"]
}
