# The provider reads the token that "terraform login" saved.
provider "tfe" {
  organization = var.organization
}

resource "tfe_project" "book" {
  name = "terraform-book-challenge"
}

# Two workspaces for one configuration, told apart by name and found by tag.
resource "tfe_workspace" "app" {
  for_each = toset(["dev", "prod"])

  name       = "ch16c-app-${each.key}"
  project_id = tfe_project.book.id

  tags = {
    app = "ch16c"
    env = each.key
  }
}

# A Terraform variable that differs per workspace.
resource "tfe_variable" "environment" {
  for_each = tfe_workspace.app

  workspace_id = each.value.id
  category     = "terraform"
  key          = "environment"
  value        = each.key
}

# Settings shared by every workspace in the project: one variable set.
resource "tfe_variable_set" "gcp" {
  name        = "ch16c-google-cloud"
  description = "Google Cloud project and dynamic provider credentials."
}

resource "tfe_project_variable_set" "gcp" {
  project_id      = tfe_project.book.id
  variable_set_id = tfe_variable_set.gcp.id
}

resource "tfe_variable" "project_id" {
  variable_set_id = tfe_variable_set.gcp.id
  category        = "terraform"
  key             = "project_id"
  value           = var.project_id
}

resource "tfe_variable" "gcp_auth" {
  for_each = {
    TFC_GCP_PROVIDER_AUTH             = "true"
    TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL = var.service_account_email
    TFC_GCP_WORKLOAD_PROVIDER_NAME    = var.workload_provider_name
  }

  variable_set_id = tfe_variable_set.gcp.id
  category        = "env"
  key             = each.key
  value           = each.value
}

output "workspaces" {
  value = { for env, ws in tfe_workspace.app : env => ws.name }
}
