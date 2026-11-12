output "files_bucket" {
  value = google_storage_bucket.files.name
}

output "files_location" {
  value = google_storage_bucket.files.location
}
