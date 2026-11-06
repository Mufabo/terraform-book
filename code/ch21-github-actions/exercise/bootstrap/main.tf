resource "google_project_service" "this" {
  for_each = toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# --- Workload Identity Federation: trust GitHub's OIDC tokens --------------

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.this]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # TODO: only accept tokens issued for var.github_repository
  # attribute_condition = "..."

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# --- Plan identity: read-only, used by pull requests ------------------------

resource "google_service_account" "plan" {
  account_id   = "tf-plan"
  display_name = "Terraform plan (pull requests)"
}

resource "google_project_iam_member" "plan" {
  for_each = toset([
    "roles/viewer",
    "roles/iam.securityReviewer", # read IAM policies (plan + terraform vet)
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.plan.email}"
}

# Any workflow run in the repository may impersonate the plan identity.
resource "google_service_account_iam_member" "plan_wif" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

# --- Apply identities: one per environment ----------------------------------

resource "google_service_account" "apply" {
  for_each = var.environments

  account_id   = "tf-apply-${each.key}"
  display_name = "Terraform apply (${each.key})"
}

# roles/editor keeps the exercise simple. In production, grant only the
# roles your configuration needs, and use a separate project per environment.
resource "google_project_iam_member" "apply_editor" {
  for_each = var.environments

  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.apply[each.key].email}"
}

# Needed to grant IAM roles (e.g. run.invoker, bucket IAM) from Terraform.
resource "google_project_iam_member" "apply_iam_admin" {
  for_each = var.environments

  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.apply[each.key].email}"
}

# Only jobs that run in the matching GitHub *environment* may impersonate
# the apply identity. The environment's protection rules (e.g. required
# reviewers for prod) therefore guard the credentials too.
resource "google_service_account_iam_member" "apply_wif" {
  for_each = var.environments

  service_account_id = google_service_account.apply[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "TODO" # TODO: principal://iam.googleapis.com/<pool name>/subject/repo:<OWNER/NAME>:environment:<env>
}

# --- State bucket access ----------------------------------------------------

# Plans lock the state, so the plan identity needs write access to lock files.
resource "google_storage_bucket_iam_member" "state" {
  for_each = merge(
    { plan = google_service_account.plan.email },
    { for env, sa in google_service_account.apply : "apply-${env}" => sa.email },
  )

  bucket = var.state_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${each.value}"
}
