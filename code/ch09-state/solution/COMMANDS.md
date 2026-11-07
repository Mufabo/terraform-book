# Chapter 9 — commands used in the solution

The solution files show the configuration *after* steps 5 and 6.

```console
# Step 5: rename without recreating
$ terraform state mv google_storage_bucket.notes google_storage_bucket.docs

# Step 6: stop managing the archive bucket
$ terraform state rm 'google_storage_bucket.this["archive"]'
# ...remove "archive" from terraform.tfvars, then delete the bucket by hand:
$ gcloud storage rm -r gs://ch09-archive-<suffix>
```

After each step, `terraform plan` shows only "Changes to Outputs" (the
renamed `docs_bucket` output, then the `other_buckets` list without the
archive bucket). Run `terraform apply` to save the outputs; it changes no
infrastructure. After that, `terraform plan` reports **No changes**.
