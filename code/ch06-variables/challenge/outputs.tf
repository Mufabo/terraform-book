output "bucket_name" {
  description = "Name of the team bucket."
  value       = google_storage_bucket.team.name
}

output "bucket_url" {
  description = "gs:// URL of the team bucket."
  value       = google_storage_bucket.team.url
}

output "summary" {
  description = "One line describing the bucket."
  value       = "${local.bucket_name}: ${var.bucket.storage_class} in ${var.bucket.location}, deleted objects restorable for ${var.bucket.soft_delete_days} days"
}
