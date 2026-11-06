output "network_id" {
  value = google_compute_network.shared.id
}

output "subnet_id" {
  value = google_compute_subnetwork.app.id
}

output "subnet_region" {
  value = google_compute_subnetwork.app.region
}

# Re-export the module output as a root output, so other configurations can
# read it through terraform_remote_state.
output "ssh_tag" {
  value = module.iap_ssh.target_tag
}
