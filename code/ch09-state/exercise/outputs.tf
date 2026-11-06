output "notes_bucket" {
  value = google_storage_bucket.notes.name
}

output "other_buckets" {
  value = [for b in google_storage_bucket.this : b.name]
}
