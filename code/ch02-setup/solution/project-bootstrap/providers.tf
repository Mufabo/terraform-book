# Creates the project. No project is set because it doesn't exist yet.
provider "google" {}

# The Service Usage and Billing Budget APIs need a "quota project" when you
# authenticate with your own user account (ADC). This aliased provider uses
# the new project for that.
provider "google" {
  alias = "quota"

  billing_project       = var.project_id
  user_project_override = true
}
