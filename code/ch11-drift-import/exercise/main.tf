# Step 2: tidy up generated.tf and move the site bucket's resource block here.

# Step 3: write google_storage_bucket.media for "<project-id>-legacy-media"
# (location EUROPE-WEST1, storage_class NEARLINE, uniform access, force_destroy = true),
# then run: terraform import google_storage_bucket.media <project-id>-legacy-media

# Step 6: rename it to "assets" and add a moved block.

# Step 7: replace it with a removed block (destroy = false).
