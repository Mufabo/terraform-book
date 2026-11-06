# The site bucket was adopted with this import block (step 2). Once imported,
# the block has no further effect and can be kept as a record or deleted.
import {
  to = google_storage_bucket.site
  id = "${var.project_id}-legacy-site"
}
