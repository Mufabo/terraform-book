# Chapter 9 challenge: splitting a configuration

Starting point: one configuration in `platform/` with
`google_storage_bucket.shared` and `google_storage_bucket.team` (two
instances), all applied. The two folders here show the end result.

1. Create `teams/` next to `platform/` with its own `versions.tf`,
   `providers.tf`, `variables.tf` (including `teams`), and a `main.tf` that
   holds the `google_storage_bucket.team` block. Copy `terraform.tfvars`.
   Don't run `apply` there.

2. Move the two state entries from `platform/`'s state file into a new state
   file in `teams/`. `terraform state mv -help` lists the option you need:

   ```console
   $ cd platform
   $ terraform state mv -state-out=../teams/terraform.tfstate \
       google_storage_bucket.team google_storage_bucket.team
   Move "google_storage_bucket.team" to "google_storage_bucket.team"
   Successfully moved 1 object(s).
   ```

   Moving the resource without an instance key moves all of its instances.
   `-state-out` only works with local state files.

3. Delete the `google_storage_bucket.team` block and the `teams` variable
   from `platform/`.

4. Check both sides:

   ```console
   $ terraform state list            # in platform/
   google_storage_bucket.shared
   $ terraform plan                  # No changes.

   $ cd ../teams && terraform init
   $ terraform state list
   google_storage_bucket.team["reports"]
   google_storage_bucket.team["shop"]
   $ terraform plan                  # No changes.
   ```

Nothing was destroyed or created: `gcloud storage buckets list` shows the
same three buckets throughout.

What would have gone wrong with the "obvious" approach (delete the block in
`platform/`, add it in `teams/`, apply both)? `platform/` would **destroy**
the two buckets, and `teams/` would create new, empty ones.

A second way with the commands from this chapter: `terraform state rm` in
`platform/`, then adopt the buckets in `teams/` with `import` (Chapter 11).

Cleanup: `terraform destroy` in both folders.
