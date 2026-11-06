provider "google" {
  project = "tf-book-fatih-12345" # your project ID
  region  = "europe-west1"
}

provider "google" {
  alias   = "us"
  project = "tf-book-fatih-12345"
  region  = "us-central1"
}

provider "google-beta" {
  project = "tf-book-fatih-12345"
  region  = "europe-west1"
}
