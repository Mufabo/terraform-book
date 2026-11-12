resource "google_storage_bucket" "records" {
  name                        = "${var.project_id}-ch08c-${var.environment}-records"
  location                    = var.location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  labels = {
    environment = var.environment
    last_audit  = "never" # an audit tool updates this label
  }

  versioning {
    enabled = var.versioning
  }

  lifecycle_rule {
    condition {
      age = var.retention_days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle {
    # A rule about a combination of inputs: a precondition, not a validation
    # of one variable.
    precondition {
      condition     = var.environment != "prod" || var.versioning
      error_message = "Production buckets must have versioning enabled (set versioning = true)."
    }

    # A guarantee about the result that others rely on.
    postcondition {
      condition     = self.public_access_prevention == "enforced"
      error_message = "The records bucket must enforce public access prevention."
    }

    ignore_changes = [
      labels["last_audit"],
    ]
  }
}

# A recommendation, not a rule: it warns and never blocks.
check "retention_is_long_enough" {
  assert {
    condition     = var.environment != "prod" || var.retention_days >= 90
    error_message = "Company guideline: production records should be kept for at least 90 days (retention_days is ${var.retention_days})."
  }
}
