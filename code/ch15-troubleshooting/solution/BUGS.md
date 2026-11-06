# Chapter 15 — the six bugs

| # | Revealed by | Category | Bug | Fix |
|---|---|---|---|---|
| 1 | `terraform init` | Language (version constraint) | `required_version = "~> 1.6.0"` rejects Terraform 1.17.0 with *Unsupported Terraform Core version*. | `required_version = "~> 1.17.0"` |
| 2 | `terraform fmt` (re-running `init` also reports it, because `init` parses the configuration) | Language (syntax) | The last `resource` block is missing its closing `}`; *Unclosed configuration block*. | Add the `}` |
| 3 | `terraform validate` | Language (reference) | `google_compute_network.webb` — *Reference to undeclared resource*. | `google_compute_network.web.id` |
| 4 | `terraform validate` | Language (argument) | `locaton` — *Unsupported argument. Did you mean "location"?* | `location` |
| 5 | `terraform plan` | Language/core (unknown values) | `for_each` keys include `random_id.suffix.hex`, which is *known only after apply* — *Invalid for_each argument*. | Use static keys (`toset(["logs", "assets"])`) and put the random suffix in the `name` argument instead. |
| 6 | `terraform apply` | Provider (API error 400/404) | `region = "europe-west99"` doesn't exist. Validation can't know which regions exist; only the Google API does. | `region = var.region` |

Things to notice:

* Each tool only finds certain kinds of errors: `init` checks versions,
  `fmt` needs parseable syntax, `validate` checks the language against the
  provider schema, `plan` needs to evaluate values, and only `apply` reaches
  the API for creation.
* The provider log (`TF_LOG_PROVIDER=DEBUG`) shows the exact `POST` request for
  the subnetwork and Google's error response for bug 6.
