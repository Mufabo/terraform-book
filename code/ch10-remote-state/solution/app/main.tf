data "terraform_remote_state" "network" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "ch10/network"
  }
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

resource "google_compute_instance" "app" {
  name         = "ch10-app"
  machine_type = "e2-micro"
  zone         = "${data.terraform_remote_state.network.outputs.subnet_region}-b"

  # Comes from a module inside the network configuration, re-exported there
  # as a root output.
  tags = [data.terraform_remote_state.network.outputs.ssh_tag]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
    }
  }

  network_interface {
    subnetwork = data.terraform_remote_state.network.outputs.subnet_id
  }
}
