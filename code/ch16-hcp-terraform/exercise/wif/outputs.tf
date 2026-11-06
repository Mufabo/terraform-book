output "workload_provider_name" {
  description = "Value for TFC_GCP_WORKLOAD_PROVIDER_NAME."
  value       = google_iam_workload_identity_pool_provider.hcp.name
}

output "service_account_email" {
  description = "Value for TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL."
  value       = google_service_account.terraform.email
}
