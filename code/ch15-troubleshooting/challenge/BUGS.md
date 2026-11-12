# Chapter 15 challenge: the four bugs

`broken/` is the starting point, `fixed/` the result.

| # | Revealed by | Category | Bug | Fix |
|---|---|---|---|---|
| 1 | `terraform validate` | Core (dependency graph) | *Error: Cycle*, naming `google_storage_bucket.data` and `google_storage_bucket.logs`. The data bucket logs to the logs bucket, and the logs bucket's label refers back to the data bucket's name. Neither can be created first. | Break one of the two references. The data bucket's name is built from variables, so put it in a local and use the local for the label. |
| 2 | `terraform validate` (only after bug 1 is fixed) | Language (type) | *Invalid for_each argument*: `var.bucket_names` is a list, and `for_each` accepts only a map or a set of strings. | `for_each = toset(var.bucket_names)` |
| 3 | `terraform plan` | Language (expression) | *Invalid index*: `var.zones[3]`, but the list has three elements, numbered 0 to 2. `validate` can't see it, because it doesn't know the variable's value. | `var.zones[0]` |
| 4 | `terraform apply` | Provider (API error 400) | The `db` subnet's range `10.90.0.128/25` lies inside the `app` subnet's `10.90.0.0/24`. Google rejects the second subnet because its range conflicts with an existing subnetwork. Only the API knows which ranges are in use. | A range that doesn't overlap, e.g. `10.90.1.0/24` |

Things to notice:

* Terraform reports the cycle **alone**. Until the graph can be built,
  nothing else is checked, so bug 2 stays hidden behind bug 1.
* `terraform graph` doesn't help with a cycle (it fails with the same
  error). Read the two addresses in the message and look for the references
  between them.
* Bug 4 leaves you with a half-finished apply: the network, the buckets, and
  one of the two subnets exist and are in state. Which subnet fails depends
  on which one Google creates first. Fix the range and apply again;
  Terraform creates only what's missing.
* To see Google's exact answer for bug 4, run the failing apply with
  `TF_LOG=DEBUG TF_LOG_PATH=./debug.log` and search for `HTTP/2.0 4`.

Cleanup: `terraform destroy`, then delete `debug.log`.
