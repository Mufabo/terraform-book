output "github_variables" {
  description = "Create these as GitHub repository variables (Settings → Secrets and variables → Actions → Variables)."
  value = merge(
    {
      GCP_PROJECT_ID   = var.project_id
      GCP_WIF_PROVIDER = google_iam_workload_identity_pool_provider.github.name
      GCP_PLAN_SA      = google_service_account.plan.email
      TF_STATE_BUCKET  = var.state_bucket
    },
    { for env, sa in google_service_account.apply : "GCP_APPLY_SA_${upper(env)}" => sa.email },
  )
}
