# Chapter 11 challenge: adopting a hand-made network

`imports.tf` and `main.tf` show the configuration after step 3.

1. **Import.** Write the three resource blocks by hand from what
   `gcloud compute networks describe ch11c-net` (and the matching `describe`
   commands for the subnet and the firewall rule) show, plus one `import`
   block each. Repeat `terraform plan` until it says
   `Plan: 3 to import, 0 to add, 0 to change, 0 to destroy`, then apply. If
   the plan shows a change, your block differs from the real object: fix the
   block, not the object.

2. **Drift.** After
   `gcloud compute firewall-rules update ch11c-allow-ssh-iap --allow=tcp:22,tcp:3389`,
   `terraform plan -refresh-only` reports the extra port, and
   `terraform plan` proposes to remove it again. `terraform apply` reverts
   the manual change.

3. **Rename.** Rename the firewall resource and add the `moved` block. The
   plan shows `has moved to` and `0 to add, 0 to change, 0 to destroy`.

4. **Release.** Replace all three resource blocks (and the `moved` and
   `import` blocks) with

   ```hcl
   removed {
     from = google_compute_network.legacy

     lifecycle {
       destroy = false
     }
   }
   ```

   and the same for `google_compute_subnetwork.legacy` and
   `google_compute_firewall.iap_ssh`. The plan says each "will no longer be
   managed by Terraform". After the apply, `terraform state list` prints
   nothing, and the network still exists.

Cleanup, in this order (a network can't be deleted while it has subnets or
firewall rules):

```console
$ gcloud compute firewall-rules delete ch11c-allow-ssh-iap
$ gcloud compute networks subnets delete ch11c-subnet --region=europe-west1
$ gcloud compute networks delete ch11c-net
```
