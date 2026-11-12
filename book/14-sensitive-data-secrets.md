# Chapter 14 — Sensitive Data and Secrets

## Learning objectives

By the end of this lesson you will be able to:

* Explain where secrets can leak in a Terraform workflow: code, variables,
  plan output, plan files, logs, and **state**. `[4h]`
* Use `sensitive = true` on variables and outputs, and explain its limits. `[4h]`
* Use **ephemeral** variables, resources, and **write-only arguments** to keep
  secrets out of state and plan files. `[4h]`
* Store and consume secrets with **Google Secret Manager**.
* Describe how **HashiCorp Vault** integrates with Terraform. `[4h]`
* Apply best practices for credentials and secrets management. `[4h]`

---

## 14.1 Where secrets leak

Infrastructure needs secrets: database passwords, API keys, TLS private keys,
service account tokens. In a Terraform workflow they can leak in many
places:

| Place | Risk |
|---|---|
| `.tf` files | Hard-coded secrets end up in Git history forever. |
| `terraform.tfvars` | Committed by mistake. |
| CLI output | Printed in plan/apply output and CI logs. |
| Saved plan files | Contain all values, including secrets. |
| **State file** | Contains every resource attribute in **plain text**. |
| Debug logs (`TF_LOG`) | May include API requests with secrets. |

The golden rules:

1. **Never hard-code secrets** in `.tf` files or commit them in tfvars.
2. **Treat state as sensitive**: remote backend, encryption, tight IAM
   (Chapter 10).
3. **Keep secrets out of state where possible** with ephemeral values and
   write-only arguments.
4. **Prefer secret managers** (Secret Manager, Vault) and short-lived,
   identity-based credentials over static secrets.

## 14.2 `sensitive = true` `[4h]`

Mark variables and outputs as sensitive to hide them in CLI output:

```hcl
variable "db_password" {
  description = "Password for the application database user."
  type        = string
  sensitive   = true
}

output "connection_string" {
  value     = "postgres://app:${var.db_password}@${google_sql_database_instance.main.private_ip_address}/app"
  sensitive = true
}
```

```console
$ terraform plan
  + resource "google_sql_user" "app" {
      + password = (sensitive value)
...
$ terraform output
connection_string = <sensitive>
$ terraform output -raw connection_string     # explicit request still shows it
postgres://app:s3cr3t@10.1.2.3/app
```

> [!NOTE]
> **Google Cloud: Cloud SQL.** **Cloud SQL** is Google Cloud's managed
> database service for PostgreSQL, MySQL, and SQL Server. Google runs the
> server, backups, and patches; you create the instance
> (`google_sql_database_instance`), databases, and users (`google_sql_user`).
> An instance can have a public IP address, a private IP address in your VPC
> network, or both. Unlike buckets, an instance costs money for every hour it
> exists, even when idle, which is why this book's exercises don't create one.

What sensitivity does:

* Hides the value in `plan` and `apply` output.
* **Propagates**: any expression that uses a sensitive value is also
  sensitive. If you put a sensitive value into a non-sensitive output,
  Terraform raises an error until you mark the output `sensitive` too.
* Providers mark many attributes sensitive automatically (e.g. passwords,
  private keys).

What it does **not** do:

* It does **not** encrypt or remove the value from **state** — the plain text
  is still there.
* It does not hide the value from `terraform output -raw`/`-json` or
  `terraform console`.

> **Exam tip:** `sensitive = true` = redacted in CLI output only. State still
> contains the value. This is one of the most frequently tested facts.

If you need to use a sensitive value somewhere it's safe to reveal
(e.g. a derived non-secret), `nonsensitive()` removes the marking — use with
care. `sensitive()` adds the marking to a value.

## 14.3 Keeping secrets out of state: ephemeral values

Terraform 1.10 and 1.11 added features that let secret values flow through a
run **without ever being stored** in the plan file or the state.

### Ephemeral input variables

```hcl
variable "db_password" {
  type      = string
  sensitive = true
  ephemeral = true
}
```

An ephemeral variable's value is available during the run but not persisted.
It can only be used in places that don't persist values: other ephemeral
contexts, provider configuration, and **write-only arguments**.

### Ephemeral resources

An `ephemeral` block is like a data source whose result is never stored:

```hcl
ephemeral "google_secret_manager_secret_version" "db_password" {
  secret = "db-password"
}
```

Its values (`ephemeral.google_secret_manager_secret_version.db_password.secret_data`)
can be passed to provider configurations and write-only arguments. Compare
with the *data source* `data "google_secret_manager_secret_version"`, whose
result **is** stored in state.

The `random` provider offers an ephemeral `random_password` that generates a
password without saving it:

```hcl
ephemeral "random_password" "db" {
  length  = 24
  special = true
}
```

### Write-only arguments

A **write-only argument** accepts a value (including ephemeral values),
sends it to the API, and never stores it in plan or state. In the Google
provider, write-only arguments end with `_wo` and come with a companion
`_wo_version` argument:

```hcl
resource "google_secret_manager_secret_version" "db_password" {
  secret                 = google_secret_manager_secret.db_password.id
  secret_data_wo         = ephemeral.random_password.db.result
  secret_data_wo_version = 1
}

resource "google_sql_user" "app" {
  name                = "app"
  instance            = google_sql_database_instance.main.name
  password_wo         = ephemeral.random_password.db.result
  password_wo_version = 1
}
```

Because Terraform doesn't store the value, it can't detect when it changes.
The `*_wo_version` number is how you tell Terraform to send a new value:
**increase it** to rotate the secret.

> **Newer than the exam:** Ephemeral resources (1.10) and write-only arguments
> (1.11) postdate parts of the exam's syllabus, but they're the modern best
> practice for keeping secrets out of state. Know that they exist.

## 14.4 Google Secret Manager

**Secret Manager** is Google Cloud's service for storing secrets with
versioning, IAM, audit logs, and automatic replication.

Concepts:

* A **secret** is a named container with IAM and replication settings.
* A **secret version** holds the actual value. New versions are added for
  rotation; old versions can be disabled or destroyed.

### Pattern 1: Terraform creates the secret, a human adds the value

```hcl
resource "google_secret_manager_secret" "api_key" {
  secret_id = "payment-api-key"

  replication {
    auto {}
  }
}
```

An authorised person adds the value outside Terraform:

```console
$ printf '%s' "the-real-key" | gcloud secrets versions add payment-api-key --data-file=-
```

The value never touches Terraform at all. Simple and very safe.

### Pattern 2: Terraform generates the value (write-only)

As in 14.3: `ephemeral "random_password"` + `secret_data_wo`. The value
exists in Secret Manager only.

### Pattern 3: The application reads the secret at runtime

The best pattern: Terraform grants an application's **service account**
permission to read the secret, and the application fetches it itself.
Terraform never handles the value.

> [!NOTE]
> **Google Cloud: workloads that run as a service account.** You can attach a
> service account to a Cloud Run service, a VM, and most other compute
> resources (`service_account` below). Code running there then asks the
> built-in **metadata server** for a short-lived token, and Google's client
> libraries do this automatically: no key file, no secret to store. If you
> don't attach one, many services use a default service account, which in
> many projects holds the broad Editor role. A dedicated service account
> with only the roles the application needs is the better choice.

```hcl
resource "google_service_account" "app" {
  account_id   = "ch14-app"
  display_name = "Chapter 14 app"
}

resource "google_secret_manager_secret_iam_member" "app_reads_key" {
  secret_id = google_secret_manager_secret.api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}

resource "google_cloud_run_v2_service" "app" {
  name                = "ch14-app"
  location            = var.region
  deletion_protection = false

  template {
    service_account = google_service_account.app.email

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      env {
        name = "API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.api_key.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.app_reads_key]
}
```

Cloud Run injects the secret as an environment variable when the container
starts. Note the `depends_on`: the service doesn't reference the IAM binding,
but needs it to start (Chapter 5).

### Avoid: reading secrets with a data source

```hcl
data "google_secret_manager_secret_version" "api_key" {
  secret = "payment-api-key"
}
```

This works, but the secret is now **stored in state**. Prefer the ephemeral
resource if Terraform really needs the value.

## 14.5 HashiCorp Vault `[4h]`

**Vault** is HashiCorp's secrets management product. The exam expects you to
know how Terraform and Vault work together:

* **Vault provider** (`hashicorp/vault`, version 5.13.0 at the time of
  writing): manage Vault itself as code — secret engines, policies, auth
  methods — and read secrets.
* **Reading secrets**: use Vault's ephemeral resources (or, older style,
  data sources such as `vault_kv_secret_v2`) to fetch a secret during a run.
* **Dynamic secrets**: Vault can generate **short-lived credentials on
  demand** — for example a Google Cloud OAuth token or service account key
  with a TTL of one hour — via its Google Cloud secrets engine. Terraform
  fetches fresh credentials at the start of a run; they expire shortly after.
  Nothing long-lived is stored anywhere.
* **HCP Terraform dynamic credentials with Vault**: HCP Terraform workspaces
  can authenticate to Vault with workload identity (OIDC) and receive a Vault
  token automatically, without storing any Vault token in the workspace.

```hcl
provider "vault" {
  address = "https://vault.example.com:8200"
  # Token comes from the VAULT_TOKEN environment variable or workload identity.
}

ephemeral "vault_kv_secret_v2" "db" {
  mount = "secret"
  name  = "prod/db"
}

resource "google_sql_user" "app" {
  name                = "app"
  instance            = google_sql_database_instance.main.name
  password_wo         = ephemeral.vault_kv_secret_v2.db.data["password"]
  password_wo_version = 3
}
```

> **Exam tip:** Know why Vault helps: centralised secrets, dynamic
> short-lived credentials, audit logging, and keeping secrets out of code.
> Also remember that a value *read* from Vault through a regular data source
> ends up in Terraform state.

## 14.6 Credentials for Terraform itself

Terraform also needs credentials to call Google Cloud. Best practices:

| Where Terraform runs | Use | Avoid |
|---|---|---|
| Your laptop | Application Default Credentials (`gcloud auth application-default login`) | Downloaded key files |
| GitHub Actions / GitLab CI | **Workload Identity Federation** (OIDC, Chapter 21) | Key file in CI secrets |
| HCP Terraform | **Dynamic provider credentials** (OIDC, Chapter 16) | Key file in a workspace variable |
| Need to act as another account | Service account **impersonation** (`impersonate_service_account` in the provider) | Sharing keys |

Impersonation example: you log in as yourself, but Terraform acts as a
dedicated service account with exactly the permissions it needs:

```hcl
provider "google" {
  project                     = var.project_id
  region                      = var.region
  impersonate_service_account = "terraform@${var.project_id}.iam.gserviceaccount.com"
}
```

You need `roles/iam.serviceAccountTokenCreator` on that service account.

> [!NOTE]
> **Google Cloud: impersonation.** **Impersonating** a service account means
> asking Google for a short-lived token *for* that service account, using
> your own credentials. Google allows it only if you hold
> `roles/iam.serviceAccountTokenCreator` on the service account, and the audit
> logs record both identities. Teams use it so that people have few
> permissions themselves, and Terraform runs with exactly the permissions of
> one well-reviewed service account. You can try it with `gcloud` too:
> `gcloud storage ls --impersonate-service-account=SA_EMAIL`.

## 14.7 Checklist

* No secrets in `.tf`, `.tfvars` in Git, or commit history (scan with tools
  such as gitleaks or GitHub secret scanning).
* `sensitive = true` on secret variables and outputs.
* Remote, encrypted state with least-privilege access and versioning.
* Ephemeral values and write-only arguments where providers support them.
* Applications read secrets at runtime from Secret Manager or Vault.
* Short-lived, identity-based credentials for Terraform itself.
* Don't save plan files or debug logs in places others can read.

## Common mistakes and exam tips

* Believing `sensitive` encrypts state.
* Reading secrets with data sources and forgetting they go into state.
* Printing secrets in CI logs via `terraform output -json`.
* Forgetting to bump `*_wo_version` when rotating a write-only secret.
* Storing service account keys in repositories.

## Summary

* Secrets can leak through code, tfvars, output, plan files, logs, and state.
* `sensitive` redacts output but doesn't keep values out of state.
* Ephemeral variables/resources and write-only arguments keep secrets out of
  plan and state.
* Secret Manager stores secrets; let applications read them at runtime.
* Vault provides centralised and dynamic secrets that integrate with
  Terraform.
* Terraform's own credentials should be short-lived and identity-based.

## Quick check

1. Does `sensitive = true` remove a value from the state file?
2. What is a write-only argument, and why does it need a `_wo_version`
   companion?
3. What's the difference between `data "google_secret_manager_secret_version"`
   and `ephemeral "google_secret_manager_secret_version"`?
4. Name two benefits of Vault's dynamic secrets.
5. How should a GitHub Actions pipeline authenticate Terraform to Google Cloud?

---

## Hands-on exercise: Secrets without leaks

**Goal:** Generate a password that never appears in state, store it in
Secret Manager, and give a Cloud Run service access to a secret at runtime.

**Estimated time:** 25 minutes

**Files:** `code/ch14-secrets/exercise/`

### Steps

1. `cd code/ch14-secrets/exercise` and create `terraform.tfvars`.
2. In `main.tf`, complete the `TODO`s:
   * Enable the Secret Manager and Cloud Run APIs.
   * Create a secret `ch14-db-password` and a version using an
     `ephemeral "random_password"` and `secret_data_wo` /
     `secret_data_wo_version`.
   * Create a secret `ch14-api-key` with **no** version (pattern 1).
   * Create a service account, grant it `secretAccessor` on `ch14-api-key`,
     and deploy the Cloud Run `hello` container with the secret as the
     environment variable `API_KEY`.
3. `terraform init` and `terraform apply`. Terraform creates the secrets and
   the service account, but the Cloud Run service fails: `ch14-api-key` has
   no version yet, so there's nothing for `API_KEY` to read. That's expected
   with pattern 1, where a human supplies the value.
4. Add the API key value yourself, then apply again:

   ```console
   $ printf '%s' "demo-key-123" | gcloud secrets versions add ch14-api-key --data-file=-
   $ terraform apply
   ```

   The plan says the service "is tainted, so must be replaced": Terraform
   marks a resource whose creation failed as tainted (Chapter 11) and
   re-creates it.
5. **Prove the password isn't in state:**

   ```console
   $ terraform state pull | grep secret_data_wo
               "secret_data_wo": null,
               "secret_data_wo_version": "1",
   $ gcloud secrets versions access latest --secret=ch14-db-password  # the real value
   $ terraform state pull | grep -cF -- "$(gcloud secrets versions access latest --secret=ch14-db-password)"
   0
   ```

   `-F` makes `grep` treat the password as plain text and `--` stops it from
   reading a leading `-` as an option; generated passwords often contain
   characters such as `[` or `*` that would otherwise break the search.

6. **Sensitive outputs:** Add an output that exposes the service URL and
   another that contains `var.demo_token` (a sensitive variable). Run
   `terraform apply` without `sensitive = true` on the second output and read
   the error. Fix it.
7. **Rotate:** Increase `secret_data_wo_version` to `2` and apply. List the
   versions with `gcloud secrets versions list ch14-db-password`. Version 2
   is `enabled` and version 1 is `destroyed`: changing the version number
   replaces the version resource, so the old password is gone.

### Expected result

Two secrets in Secret Manager, a Cloud Run service whose `API_KEY`
environment variable comes from Secret Manager, and a password that exists
only in Secret Manager — not in your state.

### Stretch goal

Add `impersonate_service_account` to the provider with a dedicated
`terraform` service account. Create it with `gcloud` first, grant yourself
`roles/iam.serviceAccountTokenCreator` on it, and grant the service account
itself the project roles it needs to manage this exercise's resources.
Without those roles, every read in `terraform plan` fails with
`Error 403: The caller does not have permission`, because Terraform now acts
only as the service account. A new service account also takes a minute to
become usable; until then, the provider reports `impersonate: status code
404`.

### Cleanup

```console
$ terraform destroy
```

---

## Quick check answers

1. No. It only redacts the value in CLI output.
2. An argument whose value is sent to the provider but never stored in plan
   or state. Because Terraform can't compare the stored value, it relies on
   the version number to know when to send a new value.
3. The data source stores the secret value in state; the ephemeral resource
   makes it available during the run without persisting it.
4. Any two: short-lived credentials, generated on demand, automatic expiry,
   unique per consumer, audited, nothing long-lived to leak.
5. With Workload Identity Federation (OIDC) — no service account keys.
