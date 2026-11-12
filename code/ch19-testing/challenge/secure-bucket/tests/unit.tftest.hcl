# Unit tests for the secure-bucket module. They run without credentials.

mock_provider "google" {}

variables {
  project_id = "test-project"
  name       = "test-project-logs"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = google_storage_bucket.this.uniform_bucket_level_access == true
    error_message = "Uniform bucket-level access must be on."
  }

  assert {
    condition     = google_storage_bucket.this.public_access_prevention == "enforced"
    error_message = "Public access prevention must be enforced."
  }

  assert {
    condition     = google_storage_bucket.this.versioning[0].enabled == true
    error_message = "Versioning must be on."
  }

  assert {
    condition     = google_storage_bucket.this.force_destroy == false
    error_message = "force_destroy must default to false."
  }

  assert {
    condition     = google_storage_bucket.this.location == "EU"
    error_message = "The default location should be EU."
  }
}

run "no_lifecycle_rule_by_default" {
  command = plan

  assert {
    condition     = length(google_storage_bucket.this.lifecycle_rule) == 0
    error_message = "retention_days = 0 must not create a lifecycle rule."
  }
}

run "retention_creates_delete_rule" {
  command = plan

  variables {
    retention_days = 30
  }

  assert {
    condition     = length(google_storage_bucket.this.lifecycle_rule) == 1
    error_message = "retention_days > 0 must create exactly one lifecycle rule."
  }

  assert {
    condition     = one(google_storage_bucket.this.lifecycle_rule[0].condition).age == 30
    error_message = "The rule's age must equal retention_days."
  }

  assert {
    condition     = one(google_storage_bucket.this.lifecycle_rule[0].action).type == "Delete"
    error_message = "The rule must delete objects."
  }
}

run "labels_are_merged" {
  command = plan

  variables {
    labels = { purpose = "logs", managed_by = "someone-else" }
  }

  assert {
    condition     = google_storage_bucket.this.labels["purpose"] == "logs"
    error_message = "Caller labels must be kept."
  }

  assert {
    condition     = google_storage_bucket.this.labels["managed_by"] == "terraform"
    error_message = "The managed_by label must always be terraform, even if the caller sets it."
  }
}

run "one_iam_member_per_reader" {
  command = plan

  variables {
    readers = ["user:ana@example.com", "group:auditors@example.com"]
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.readers) == 2
    error_message = "Each reader must get its own IAM member."
  }

  assert {
    condition = alltrue([
      for m in google_storage_bucket_iam_member.readers : m.role == "roles/storage.objectViewer"
    ])
    error_message = "Readers must only get roles/storage.objectViewer."
  }
}

run "no_iam_members_without_readers" {
  command = plan

  assert {
    condition     = length(google_storage_bucket_iam_member.readers) == 0
    error_message = "No readers, no IAM members."
  }
}

run "rejects_invalid_name" {
  command = plan

  variables {
    name = "Has_Upper_Case"
  }

  expect_failures = [
    var.name,
  ]
}

run "outputs_expose_the_bucket" {
  command = apply # against the mock: nothing is created

  assert {
    condition     = output.name == "test-project-logs"
    error_message = "The name output must be the bucket name."
  }
}
