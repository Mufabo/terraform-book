locals {
  # One object per team/environment pair ...
  team_environments = flatten([
    for team, cfg in var.teams : [
      for env in cfg.environments : {
        team        = team
        environment = env
        location    = cfg.location
      }
    ]
  ])

  # ... turned into a map with a unique, stable key for for_each.
  buckets = {
    for b in local.team_environments : "${b.team}-${b.environment}" => b
  }
}

resource "google_storage_bucket" "team" {
  for_each = local.buckets

  name                        = "${var.project_id}-${each.key}"
  location                    = each.value.location
  uniform_bucket_level_access = true
  force_destroy               = true

  labels = {
    team        = each.value.team
    environment = each.value.environment
  }

  # Only non-prod buckets get the clean-up rule.
  dynamic "lifecycle_rule" {
    for_each = each.value.environment == "prod" ? [] : [var.temporary_days]
    content {
      condition {
        age = lifecycle_rule.value
      }
      action {
        type = "Delete"
      }
    }
  }
}
