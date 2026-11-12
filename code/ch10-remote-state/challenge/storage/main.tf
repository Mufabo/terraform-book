data "terraform_remote_state" "network" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "ch10/network"
  }
}

# A regional bucket in the same region as the network's subnet.
resource "google_storage_bucket" "files" {
  name                        = "${var.project_id}-ch10c-files"
  location                    = upper(data.terraform_remote_state.network.outputs.subnet_region)
  uniform_bucket_level_access = true
  force_destroy               = true
}
