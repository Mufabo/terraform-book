output "network_id" {
  description = "ID of the VPC network."
  value       = google_compute_network.this.id
}

output "subnet_id" {
  description = "ID of the subnet."
  value       = google_compute_subnetwork.this.id
}
