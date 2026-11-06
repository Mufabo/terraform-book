policy "restrict-bucket-location" {
  source            = "./restrict-bucket-location.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "require-labels" {
  source            = "./require-labels.sentinel"
  enforcement_level = "soft-mandatory"
}
