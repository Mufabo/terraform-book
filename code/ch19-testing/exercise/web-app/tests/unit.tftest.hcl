# Unit tests: run against a mocked Google provider. No credentials, no cost.
#   terraform init
#   terraform test -filter=tests/unit.tftest.hcl

mock_provider "google" {
  mock_resource "google_cloud_run_v2_service" {
    defaults = {
      uri = "https://dev-web-shop-abc123-ew.a.run.app"
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

  # TODO: assert that the bucket name is "test-project-dev-web-shop-uploads"
}

# TODO: run "bucket_is_private_and_labelled"
#   assert public_access_prevention == "enforced"
#   assert uniform_bucket_level_access is true
#   assert labels["environment"] == "dev"

# TODO: run "public_access_can_be_disabled"
#   set variables { public = false } and assert there are no
#   google_cloud_run_v2_service_iam_member.public instances

# TODO: run "outputs_use_computed_values" with command = apply
#   assert output.url equals the mocked uri

# TODO: run "rejects_unknown_environment"
#   set environment = "qa" and use expect_failures = [var.environment]

# TODO: run "rejects_too_many_instances"
#   set max_instances = 100 and expect a failure of var.max_instances
