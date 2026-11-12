# Chapter 16 challenge: workspaces as code

> Like the rest of Part V, this solution was validated with
> `terraform validate` but not run against a real organisation.

**The workspaces** (`main.tf`): one project, two workspaces created with
`for_each`, a per-workspace Terraform variable `environment`, and one
variable set attached to the **project** that holds `project_id` and the
three `TFC_GCP_*` environment variables. Apply it locally after
`terraform login`.

**The Google side.** The `wif/` binding from the exercise only trusts the
workspace named in `hcp_workspace`. Two workspaces need two bindings, so
apply `wif/` with a binding per workspace name (`ch16c-app-dev`,
`ch16c-app-prod`), for example by turning `hcp_workspace` into a set and the
binding into a `for_each`.

**The app configuration.** Select the workspaces by tag instead of by name:

```hcl
terraform {
  cloud {
    organization = "tf-book-yourname"

    workspaces {
      project = "terraform-book-challenge"
      tags    = { app = "ch16c" }
    }
  }
}
```

Give the bucket a name that contains `var.environment`, so the two
workspaces don't fight over one bucket. Then:

```console
$ terraform init
$ terraform workspace list
  ch16c-app-dev
  ch16c-app-prod
$ terraform workspace select ch16c-app-dev
$ terraform apply
$ terraform workspace select ch16c-app-prod
$ terraform apply
```

With `tags`, the CLI's `workspace` commands switch between HCP Terraform
workspaces. Each has its own state and its own value of `environment`; the
shared settings come from the variable set.

Cleanup: `terraform destroy` in each workspace, then `terraform destroy` in
this folder (it deletes the workspaces, the variable set, and the project).
