# Chapter 10 challenge: a third configuration, and moving its state

1. Copy `backend.hcl.example` to `backend.hcl` and
   `terraform.tfvars.example` to `terraform.tfvars`; fill in your bucket.
   The network configuration from the exercise must be applied.

   ```console
   $ terraform init -backend-config=backend.hcl
   $ terraform apply
   $ gcloud storage ls -r gs://<state-bucket>/ch10/
   ```

   The state is at `ch10/storage/default.tfstate`. The bucket's location
   comes from the network configuration's `subnet_region` output.

2. Move the state to the prefix `ch10/files`: change `prefix` in
   `backend.hcl`, then

   ```console
   $ terraform init -migrate-state -backend-config=backend.hcl
   ```

   Answer `yes`. `terraform plan` shows no changes. The old object
   `ch10/storage/default.tfstate` is still in the bucket: migration
   **copies** the state, it doesn't delete the source. Remove it with
   `gcloud storage rm gs://<state-bucket>/ch10/storage/default.tfstate` so
   nobody uses it by mistake.

3. With plain `terraform init -backend-config=backend.hcl` (no
   `-migrate-state`) Terraform stops with *Backend configuration changed* and
   tells you to choose between `-migrate-state` and `-reconfigure`. With
   `-reconfigure` it would use the new, empty prefix, and the next plan would
   want to create the bucket again.

Cleanup: `terraform destroy`.
