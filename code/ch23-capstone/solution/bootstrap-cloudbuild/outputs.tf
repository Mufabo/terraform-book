output "triggers" {
  description = "Names of the Cloud Build triggers."
  value       = concat(values(google_cloudbuild_trigger.plan)[*].name, values(google_cloudbuild_trigger.apply)[*].name)
}

output "plan_service_account" {
  value = google_service_account.plan.email
}

output "apply_service_accounts" {
  value = { for env, sa in google_service_account.apply : env => sa.email }
}
