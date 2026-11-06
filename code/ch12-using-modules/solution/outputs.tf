output "network_name" {
  value = module.vpc.network_name
}

output "subnet_names" {
  value = module.vpc.subnets_names
}

output "bucket_names" {
  value = module.buckets.names_list
}

output "web_ip" {
  value = google_compute_instance.web.network_interface[0].access_config[0].nat_ip
}
