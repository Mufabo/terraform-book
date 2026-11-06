# Allows SSH only from Google's Identity-Aware Proxy range, and only to VMs
# that carry the network tag below.
locals {
  target_tag = "${var.name}-iap-ssh"
}

resource "google_compute_firewall" "iap_ssh" {
  name    = "${var.name}-allow-iap-ssh"
  network = var.network_id

  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = [local.target_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
