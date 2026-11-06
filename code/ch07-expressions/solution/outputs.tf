output "subnet_ranges" {
  description = "Map of subnet name to CIDR range."
  value       = { for name, subnet in google_compute_subnetwork.this : name => subnet.ip_cidr_range }
}

output "bucket_urls" {
  description = "gs:// URLs of all buckets."
  value       = [for bucket in google_storage_bucket.this : bucket.url]
}

output "ssh_firewall_name" {
  description = "Name of the SSH firewall rule, or null if it is disabled."
  value       = one(google_compute_firewall.ssh[*].name)
}
