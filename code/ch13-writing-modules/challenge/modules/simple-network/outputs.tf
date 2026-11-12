output "network_id" {
  description = "ID of the network."
  value       = google_compute_network.this.id
}

output "subnet_ids" {
  description = "Subnet IDs, keyed by the short names from var.subnets."
  value       = { for key, subnet in google_compute_subnetwork.this : key => subnet.id }
}

output "ssh_tag" {
  description = "Network tag that allows IAP SSH, or null when enable_iap_ssh is false."
  value       = var.enable_iap_ssh ? "${var.name}-ssh" : null
}
