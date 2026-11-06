output "logs_url" {
  value = module.logs.url
}

output "report_urls" {
  value = { for dept, bucket in module.reports : dept => bucket.url }
}
