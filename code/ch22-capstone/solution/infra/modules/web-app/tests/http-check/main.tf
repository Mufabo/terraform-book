# Helper module used only by the integration test.
terraform {
  required_version = ">= 1.9"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "3.6.3"
    }
  }
}

variable "url" {
  description = "URL to request."
  type        = string
}

data "http" "service" {
  url = var.url

  retry {
    attempts     = 5
    min_delay_ms = 2000
  }
}

output "status_code" {
  description = "HTTP status code returned by the URL."
  value       = data.http.service.status_code
}
