output "networks" {
  description = "Network name and subnet per environment."
  value = {
    for env, vpc in module.vpc : env => {
      network = vpc.network_name
      subnet  = vpc.subnets_self_links[0]
      range   = vpc.subnets_ips[0]
    }
  }
}

output "bucket_names" {
  value = module.buckets.names_list
}
