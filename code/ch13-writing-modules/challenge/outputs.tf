output "dev_subnets" {
  value = module.network_dev.subnet_ids
}

output "dev_ssh_tag" {
  value = module.network_dev.ssh_tag
}

output "test_subnets" {
  value = module.network_test.subnet_ids
}
