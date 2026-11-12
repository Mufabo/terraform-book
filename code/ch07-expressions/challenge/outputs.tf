output "buckets_by_team" {
  description = "Bucket names grouped by team."
  value = {
    for key, b in google_storage_bucket.team : b.labels.team => b.name...
  }
}

output "prod_bucket_urls" {
  description = "URLs of the prod buckets only."
  value       = [for key, b in google_storage_bucket.team : b.url if b.labels.environment == "prod"]
}
