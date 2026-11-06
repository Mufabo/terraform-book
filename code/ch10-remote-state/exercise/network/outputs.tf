output "network_id" {
  value = google_compute_network.shared.id
}

output "subnet_id" {
  value = google_compute_subnetwork.app.id
}

output "subnet_region" {
  value = google_compute_subnetwork.app.region
}

# TODO (step 7): add a root output "ssh_tag" whose value is the iap_ssh
# module's target_tag output.
