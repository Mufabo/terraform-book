output "target_tag" {
  description = "Network tag that a VM needs for the rule to apply."
  value       = local.target_tag
}

output "firewall_name" {
  description = "Name of the firewall rule."
  value       = google_compute_firewall.iap_ssh.name
}
