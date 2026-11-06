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

# TODO: google_iam_workload_identity_pool_provider "hcp"
#   - provider id "hcp-terraform-oidc"
#   - attribute_mapping: google.subject = assertion.sub, plus
#     attribute.terraform_organization_name and attribute.terraform_workspace_name
#   - attribute_condition: only tokens from var.hcp_organization
#   - oidc { issuer_uri = "https://app.terraform.io" }

# TODO: google_service_account "terraform" (account_id "hcp-terraform-dev")

# TODO: google_service_account_iam_member "hcp_workload_identity" granting
#   roles/iam.workloadIdentityUser to
#   principalSet://iam.googleapis.com/<pool name>/attribute.terraform_workspace_name/<workspace>

# TODO: google_project_iam_member "terraform_editor" granting roles/editor
#   to the service account
