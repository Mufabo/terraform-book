# Integration test: creates REAL resources in Google Cloud, checks them, and
# destroys them again. Run it explicitly:
#
#   TF_VAR_project_id=<your-project> terraform test -filter=tests/integration.tftest.hcl
#
# It needs credentials (ADC) and takes a couple of minutes.

provider "google" {
  project = var.project_id
  region  = "europe-west1"
}

variables {
  region      = "europe-west1"
  environment = "dev"
  app_name    = "tftest"
}

run "service_responds" {
  command = apply

  assert {
    condition     = startswith(output.url, "https://")
    error_message = "The service did not get an https URL."
  }
}

run "service_returns_200" {
  command = plan

  module {
    source = "./tests/http-check"
  }

  variables {
    url = run.service_responds.url
  }

  assert {
    condition     = data.http.service.status_code == 200
    error_message = "The service did not return HTTP 200."
  }
}
