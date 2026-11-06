# Unit tests: run against a mocked Google provider. No credentials, no cost.

mock_provider "google" {
  # Give computed attributes realistic values instead of random strings.
  mock_resource "google_cloud_run_v2_service" {
    defaults = {
      uri = "https://dev-web-shop-abc123-ew.a.run.app"
    }
  }

  mock_resource "google_service_account" {
    defaults = {
      email = "dev-web-shop@test-project.iam.gserviceaccount.com"
    }
  }
}

variables {
  project_id  = "test-project"
  region      = "europe-west1"
  environment = "dev"
}

run "names_follow_convention" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.app.name == "dev-web-shop"
    error_message = "Service name should be <environment>-<app_name>."
  }

  assert {
    condition     = google_storage_bucket.uploads.name == "test-project-dev-web-shop-uploads"
    error_message = "Bucket name should be <project>-<environment>-<app_name>-uploads."
  }
}

run "bucket_is_private_and_labelled" {
  command = plan

  assert {
    condition     = google_storage_bucket.uploads.public_access_prevention == "enforced"
    error_message = "The uploads bucket must enforce public access prevention."
  }

  assert {
    condition     = google_storage_bucket.uploads.uniform_bucket_level_access
    error_message = "The uploads bucket must use uniform bucket-level access."
  }

  assert {
    condition     = google_storage_bucket.uploads.labels["environment"] == "dev"
    error_message = "Resources must carry an environment label."
  }
}

run "public_access_can_be_disabled" {
  command = plan

  variables {
    public = false
  }

  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.public) == 0
    error_message = "No allUsers binding may exist when public = false."
  }
}

run "scaling_settings_are_passed_through" {
  command = plan

  variables {
    min_instances = 1
    max_instances = 7
  }

  assert {
    condition     = google_cloud_run_v2_service.app.template[0].scaling[0].max_instance_count == 7
    error_message = "max_instances was not applied to the service."
  }
}

run "outputs_use_computed_values" {
  # apply against the mock provider: nothing is created in Google Cloud,
  # but computed attributes (like uri) get the mocked values.
  command = apply

  assert {
    condition     = output.url == "https://dev-web-shop-abc123-ew.a.run.app"
    error_message = "The url output should expose the service URI."
  }

  assert {
    condition     = endswith(output.service_account_email, ".iam.gserviceaccount.com")
    error_message = "The service account output should be an email address."
  }
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [
    var.environment,
  ]
}

run "rejects_too_many_instances" {
  command = plan

  variables {
    max_instances = 100
  }

  expect_failures = [
    var.max_instances,
  ]
}
