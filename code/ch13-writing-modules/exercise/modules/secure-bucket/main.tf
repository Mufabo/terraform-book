# TODO: google_storage_bucket "this" with
#   - uniform_bucket_level_access = true
#   - public_access_prevention    = "enforced"
#   - versioning enabled
#   - labels merged with { managed_by = "terraform" }
#   - a dynamic "lifecycle_rule" that deletes objects older than
#     var.retention_days, only when retention_days > 0

# TODO: google_storage_bucket_iam_member "readers" with for_each = var.readers,
#   role roles/storage.objectViewer
