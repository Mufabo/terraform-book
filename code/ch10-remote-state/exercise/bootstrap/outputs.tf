output "state_bucket" {
  description = "Name of the Terraform state bucket."
  value       = google_storage_bucket.tfstate.name
}
