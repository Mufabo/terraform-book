# gcloud projects create + gcloud billing projects link
resource "google_project" "book" {
  project_id      = var.project_id
  name            = "Terraform Book"
  billing_account = var.billing_account

  # The provider protects projects from `terraform destroy` by default.
  # "DELETE" lets you remove the learning project with Terraform.
  deletion_policy = "DELETE"
}

# gcloud services enable billingbudgets.googleapis.com
resource "google_project_service" "billingbudgets" {
  provider = google.quota

  project            = google_project.book.project_id
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = false
}

# gcloud billing budgets create
resource "google_billing_budget" "book" {
  provider = google.quota

  billing_account = var.billing_account
  display_name    = "terraform-book-budget"

  budget_filter {
    # Budgets filter by project number, not project ID.
    projects = ["projects/${google_project.book.number}"]
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.budget_amount)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }

  depends_on = [google_project_service.billingbudgets]
}

# gcloud services enable compute.googleapis.com storage.googleapis.com ...
# for_each (Chapter 7) creates one google_project_service per API in the set.
resource "google_project_service" "book" {
  provider = google.quota
  for_each = var.services

  project            = google_project.book.project_id
  service            = each.value
  disable_on_destroy = false
}
