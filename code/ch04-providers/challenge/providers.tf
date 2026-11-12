# Default configuration: Europe.
provider "google" {
  project = "tf-book-fatih-12345" # your project ID
  region  = "europe-west1"
}

# Additional configuration: United States.
provider "google" {
  alias   = "us"
  project = "tf-book-fatih-12345" # your project ID
  region  = "us-central1"
}
