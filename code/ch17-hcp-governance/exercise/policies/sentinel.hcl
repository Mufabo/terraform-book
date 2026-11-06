policy "restrict-bucket-location" {
  source            = "./restrict-bucket-location.sentinel"
  enforcement_level = "advisory" # step 10: change to "hard-mandatory"
}
