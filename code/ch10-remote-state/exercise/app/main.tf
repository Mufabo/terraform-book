# TODO: data "terraform_remote_state" "network" using the gcs backend,
# bucket = var.state_bucket and prefix = "ch10/network"

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

resource "google_compute_instance" "app" {
  name         = "ch10-app"
  machine_type = "e2-micro"
  zone         = "europe-west1-b" # TODO (optional): "${<subnet_region output>}-b"

  # TODO (step 7): tags = [<the network's ssh_tag output>]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
    }
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  network_interface {
    subnetwork = "TODO" # TODO: the subnet_id output of the network configuration
  }
}
