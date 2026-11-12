# One import block per hand-made object. The IDs are the full resource names
# (see the "Import" section of each resource's documentation page).
import {
  to = google_compute_network.legacy
  id = "projects/${var.project_id}/global/networks/ch11c-net"
}

import {
  to = google_compute_subnetwork.legacy
  id = "projects/${var.project_id}/regions/europe-west1/subnetworks/ch11c-subnet"
}

import {
  to = google_compute_firewall.iap_ssh
  id = "projects/${var.project_id}/global/firewalls/ch11c-allow-ssh-iap"
}
