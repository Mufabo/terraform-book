resource "google_project_service" "this" {
  for_each = toset([
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# --- Service accounts --------------------------------------------------------

resource "google_service_account" "plan" {
  account_id   = "cb-tf-plan"
  display_name = "Cloud Build: Terraform plan (pull requests)"

  depends_on = [google_project_service.this]
}

resource "google_service_account" "apply" {
  for_each = var.environments

  account_id   = "cb-tf-apply-${each.key}"
  display_name = "Cloud Build: Terraform apply (${each.key})"

  depends_on = [google_project_service.this]
}

locals {
  all_build_accounts = merge(
    { plan = google_service_account.plan.email },
    { for env, sa in google_service_account.apply : "apply-${env}" => sa.email },
  )

  plan_roles = [
    "roles/viewer",
    "roles/iam.securityReviewer", # read IAM policies (plan + terraform vet)
  ]

  # roles/editor keeps the exercise simple. In production, grant only the
  # roles your configuration needs, in a separate project per environment.
  apply_roles = [
    "roles/editor",
    "roles/resourcemanager.projectIamAdmin",
  ]
}

# Every build account must be able to write build logs.
resource "google_project_iam_member" "log_writer" {
  for_each = local.all_build_accounts

  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${each.value}"
}

resource "google_project_iam_member" "plan" {
  for_each = toset(local.plan_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.plan.email}"
}

resource "google_project_iam_member" "apply" {
  for_each = {
    for pair in setproduct(var.environments, local.apply_roles) : "${pair[0]}-${pair[1]}" => {
      env  = pair[0]
      role = pair[1]
    }
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.apply[each.value.env].email}"
}

resource "google_storage_bucket_iam_member" "state" {
  for_each = local.all_build_accounts

  bucket = var.state_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${each.value}"
}

# --- Triggers ------------------------------------------------------------------
# Prerequisite: connect the GitHub repository to Cloud Build once in the console
# (Cloud Build → Triggers → Connect repository → GitHub (Cloud Build GitHub App)).

resource "google_cloudbuild_trigger" "plan" {
  for_each = var.environments

  name            = "tf-plan-${each.key}"
  description     = "Terraform checks, plan, and policy check for ${each.key} on pull requests"
  location        = "global"
  filename        = "cloudbuild/plan.yaml"
  service_account = google_service_account.plan.id

  github {
    owner = var.github_owner
    name  = var.github_repository

    pull_request {
      branch          = "^main$"
      comment_control = "COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY"
    }
  }

  included_files = ["infra/**", "policy-library/**", "cloudbuild/**"]

  substitutions = {
    _ENV          = each.key
    _STATE_BUCKET = var.state_bucket
  }
}

resource "google_cloudbuild_trigger" "apply" {
  for_each = var.environments

  name            = "tf-apply-${each.key}"
  description     = "Terraform plan, policy check, and apply for ${each.key} on pushes to main"
  location        = "global"
  filename        = "cloudbuild/apply.yaml"
  service_account = google_service_account.apply[each.key].id

  github {
    owner = var.github_owner
    name  = var.github_repository

    push {
      branch = "^main$"
    }
  }

  included_files = ["infra/**", "policy-library/**", "cloudbuild/**"]

  # TODO: add an approval_config block so builds for environments in
  # var.approval_environments wait for a manual approval.

  substitutions = {
    _ENV          = each.key
    _STATE_BUCKET = var.state_bucket
  }
}
