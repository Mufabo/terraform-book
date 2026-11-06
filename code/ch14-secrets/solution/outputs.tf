output "service_url" {
  value = google_cloud_run_v2_service.app.uri
}

output "demo_token_echo" {
  value     = "token=${var.demo_token}"
  sensitive = true # step 6: required because the value is derived from a sensitive variable
}
