# Appendix E — Creating the Project with Terraform

Chapter 2 creates your learning project with `gcloud` commands, because at
that point you haven't used Terraform yet. Teams create projects with
Terraform itself: the project, its billing link, its budget, and its APIs are
then reviewed and versioned like any other code. This appendix shows the
Terraform version of sections 2.4 and 2.5.

Read it after Chapter 4. It uses the core workflow (Chapter 3), an aliased
provider (Chapter 4), and `for_each` (explained in Chapter 7), and it needs
the credentials from section 2.6. Nothing else in the book depends on it.

## E.1 The project, its billing link, and its budget

Each `gcloud` command from section 2.4 has a matching resource:

| `gcloud` command | Terraform resource |
|---|---|
| `gcloud projects create` | `google_project` |
| `gcloud billing projects link` | `billing_account` argument of `google_project` |
| `gcloud services enable billingbudgets.googleapis.com` | `google_project_service` |
| `gcloud billing budgets create` | `google_billing_budget` |
| `gcloud config set project` | *(none — this is a local `gcloud` setting)* |

The complete configuration is in `code/ch02-setup/solution/project-bootstrap/`.
The core of it:

```hcl
resource "google_project" "book" {
  project_id      = var.project_id
  name            = "Terraform Book"
  billing_account = var.billing_account

  # The provider protects projects from `terraform destroy` by default.
  # "DELETE" lets you remove the learning project with Terraform.
  deletion_policy = "DELETE"
}

resource "google_billing_budget" "book" {
  provider = google.quota

  billing_account = var.billing_account
  display_name    = "terraform-book-budget"

  budget_filter {
    # Budgets store projects by number. The API converts an ID to a number,
    # so using the ID here would show a change on every plan.
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
  # ... 0.9 and 1.0 in the same way

  depends_on = [google_project_service.billingbudgets]
}
```

To use it, copy `terraform.tfvars.example` to `terraform.tfvars`, fill in your
project ID and billing account, and run `terraform init` and
`terraform apply`. If you already created your project with `gcloud`, use a
**new** project ID here; Terraform can't create a project that already
exists. (Alternatively, bring the existing project under Terraform's control
with an `import` block, section 11.5.)

If the budget fails with an error saying the Billing Budget API is not
enabled, wait a minute and run `terraform apply` again: a newly enabled API
can take a moment to become active.

Three things are different from the `gcloud` version in section 2.4:

* **The quota project.** When Terraform uses your personal credentials, the
  Budget and Service Usage APIs need a project to bill API calls to. The
  configuration therefore has a second, aliased provider (`google.quota`,
  Chapter 4) that uses the new project for this.
* **The currency** in `budget_currency` must match your billing account's
  currency, or the API rejects the budget.
* **Keep the state file.** This configuration's state is now the record of
  your project. If you lose it, Terraform no longer knows the project exists.
  `terraform destroy` here deletes the whole project and everything in it.

## E.2 Enabling the APIs

The same configuration also enables the APIs from section 2.5. One
`google_project_service` resource per API would mean eight nearly identical
blocks, so it uses `for_each` (Chapter 7) to create one for each entry in a
set:

```hcl
variable "services" {
  description = "APIs to enable in the project (section 2.5)."
  type        = set(string)
  default = [
    "compute.googleapis.com",
    "storage.googleapis.com",
    # ... the same list as the gcloud command in section 2.5
  ]
}

resource "google_project_service" "book" {
  provider = google.quota
  for_each = var.services

  project            = google_project.book.project_id
  service            = each.value
  disable_on_destroy = false
}
```

* `disable_on_destroy = false` keeps the APIs enabled when you destroy the
  resource. Disabling an API that other resources still use breaks them, so
  this is the safe choice.
* To enable another API later, add it to the list and run `terraform apply`.
* Like the budget, this resource uses the `google.quota` provider, because
  the Service Usage API needs a quota project when you use your own
  credentials.
