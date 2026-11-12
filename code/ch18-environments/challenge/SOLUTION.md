# Chapter 18 challenge: one configuration, a tfvars file per environment

```console
$ export TF_STATE_BUCKET=<your-state-bucket>
$ ./tf.sh dev apply
$ ./tf.sh prod apply
$ gcloud storage ls -r gs://$TF_STATE_BUCKET/ch18c/
```

**The trap in this strategy** is combining one environment's backend with
another environment's values:

```console
$ terraform init -reconfigure -backend-config="prefix=ch18c/prod" ...
$ terraform plan -var-file=dev.tfvars
```

This plan reads **prod's state** and compares it with **dev's values**. It
proposes to replace the prod service and bucket with ones named `dev-...`.
Nothing in the code stops you. `tf.sh` removes the opportunity: one argument
selects both the backend prefix and the tfvars file.

**Why `-reconfigure` and not `-migrate-state`?** Switching environments is
not a migration. `-migrate-state` would offer to copy dev's state over
prod's.

**Compared with a directory per environment** (the exercise):

| | tfvars per environment | Directory per environment |
|---|---|---|
| Code duplication | None | A small `main.tf` per environment |
| Which environment am I in? | Whatever the last `init` selected | The folder you're in |
| Wrong backend with wrong values | Possible without a wrapper | Not possible |
| A resource only prod has | Needs `count` and a variable | Just add it in `envs/prod` |
| Dev on a newer module version than prod | Not possible | Possible |

Cleanup: `./tf.sh dev destroy`; for prod, set `deletion_protection = false`
in `prod.tfvars`, `./tf.sh prod apply`, then `./tf.sh prod destroy`.
