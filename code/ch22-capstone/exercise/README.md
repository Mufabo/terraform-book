# Capstone — web-shop platform

Build the complete web-shop infrastructure on your own, reusing what you
wrote in Chapters 18–21. Start from your Chapter 21 repository (or copy
`code/ch21-github-actions/solution/repo`).

Compare your result with `code/ch22-capstone/solution/` when you're done.

## Requirements

### Modules

1. `infra/modules/network` (new): a VPC without auto-created subnets and one
   subnet per environment with Private Google Access. Inputs: `project_id`,
   `region`, `name`, `subnet_cidr` (validated). Outputs: `network_id`,
   `subnet_id`.
2. `infra/modules/web-app` (extend):
   * optional `subnet_id` → Cloud Run **Direct VPC egress**
     (`template.vpc_access`, egress `PRIVATE_RANGES_ONLY`), disabled when
     `null`;
   * `secret_env` map (env var name → Secret Manager secret ID) → env vars via
     `value_source.secret_key_ref` and a `secretAccessor` binding per secret for
     the runtime service account.
3. Unit tests (mocked) for both new features. All tests pass with
   `terraform test -filter=tests/unit.tftest.hcl`.

### Environments

4. `infra/envs/dev` and `infra/envs/prod` each create:
   * the network (`10.10.0.0/24` for dev, `10.20.0.0/24` for prod),
   * a Secret Manager secret `<env>-web-shop-api-key` whose value is generated
     with an **ephemeral** `random_password` and stored via a **write-only**
     argument (never in state),
   * the web app connected to the subnet with `API_KEY` from the secret.
5. prod uses `deletion_protection = true` and allows more instances.
6. State in your GCS bucket under `envs/dev` and `envs/prod`; providers pinned
   (`google` 8.9.0, `random` 3.9.1), Terraform `~> 1.17.0`, lock files committed.

### Quality gates

7. `terraform fmt -check -recursive`, TFLint (Google ruleset) clean.
8. `gcloud beta terraform vet` passes with the Chapter 20 policy library.
   Add one new constraint of your choice (e.g. only `e2-` machine types, or
   Secret Manager secrets must carry an `environment` label).

### Delivery

9. Deploy with GitHub Actions (Chapter 21): PR checks + plan comments, dev
   auto-apply, prod behind a required reviewer (needs a public repository,
   or a paid plan for a private one).
10. Prove it works: open a PR that changes `max_instances`, show the plans,
    merge, approve prod, and call both service URLs with an identity token
    (the services are private; the policy library bans `allUsers`).

### Documentation

11. A `README.md` in your repository describing the layout, how to run checks
    locally, and how to deploy.

## Cleanup

Destroy prod (after disabling deletion protection), then dev, then the
bootstrap configuration. Delete the secrets' leftover versions if any remain.

The subnets can't be deleted until Google releases the
`serverless-ipv4-cloudrun-...` addresses that Direct VPC egress reserved,
some time after the Cloud Run services are gone. If `terraform destroy` stops
with `resourceInUseByAnotherResource`, wait an hour or two and run it again.

The reference solution's `bootstrap-github/` uses the pool ID
`web-shop-github`, not Chapter 21's `github`: a deleted pool's ID stays
reserved for 30 days. If your Chapter 21 bootstrap still exists, reuse it
instead of applying a second one (both create the same service accounts).
