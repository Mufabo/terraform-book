output "bucket_url" {
  description = "gs:// URL of the assets bucket."
  value       = google_storage_bucket.assets.url
}

output "network_id" {
  description = "ID of the VPC network."
  value       = google_compute_network.main.id
}

output "subnet_cidr" {
  description = "CIDR range of the subnet."
  value       = google_compute_subnetwork.main.ip_cidr_range
}
