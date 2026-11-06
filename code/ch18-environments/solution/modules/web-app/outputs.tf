output "url" {
  description = "URL of the Cloud Run service."
  value       = google_cloud_run_v2_service.app.uri
}

output "service_name" {
  description = "Name of the Cloud Run service."
  value       = google_cloud_run_v2_service.app.name
}

output "bucket_name" {
  description = "Name of the uploads bucket."
  value       = google_storage_bucket.uploads.name
}

output "service_account_email" {
  description = "Runtime service account of the service."
  value       = google_service_account.app.email
}
