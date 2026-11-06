resource "google_project_service" "this" {
  for_each = toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "hcp" {
  workload_identity_pool_id = "hcp-terraform"
  display_name              = "HCP Terraform"

  depends_on = [google_project_service.this]
}

resource "google_iam_workload_identity_pool_provider" "hcp" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.hcp.workload_identity_pool_id
  workload_identity_pool_provider_id = "hcp-terraform-oidc"
  display_name                       = "HCP Terraform OIDC"

  attribute_mapping = {
    "google.subject"                        = "assertion.sub"
    "attribute.terraform_organization_name" = "assertion.terraform_organization_name"
    "attribute.terraform_workspace_name"    = "assertion.terraform_workspace_name"
  }

  # Only accept tokens from our organisation.
  attribute_condition = "assertion.terraform_organization_name == \"${var.hcp_organization}\""

  oidc {
    issuer_uri = "https://app.terraform.io"
  }
}

resource "google_service_account" "terraform" {
  account_id   = "hcp-terraform-dev"
  display_name = "Runs Terraform from HCP Terraform (dev)"
}

# Allow runs of one specific workspace to impersonate the service account.
resource "google_service_account_iam_member" "hcp_workload_identity" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.hcp.name}/attribute.terraform_workspace_name/${var.hcp_workspace}"
}

# What the service account may do in the project. roles/editor keeps the
# exercise simple; production setups should grant narrower roles.
resource "google_project_iam_member" "terraform_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}
