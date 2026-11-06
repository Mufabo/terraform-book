# A random token written into the site bucket. Used in step 5 (-replace).
resource "random_id" "token" {
  byte_length = 8
}

resource "google_storage_bucket_object" "token" {
  name    = "token.txt"
  bucket  = "${var.project_id}-legacy-site" # after step 2 you can use google_storage_bucket.site.name
  content = random_id.token.hex
}
