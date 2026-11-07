# Chapter 15 — Troubleshooting and Logging

## Learning objectives

By the end of this lesson you will be able to:

* Classify Terraform errors: language, state, core, and provider errors.
* Read Terraform error messages and find the root cause quickly.
* Describe when and how to use **verbose logging** with `TF_LOG` and
  `TF_LOG_PATH`. `[7c]`
* Separate core and provider logs with `TF_LOG_CORE` and `TF_LOG_PROVIDER`. `[7c]`
* Use `validate`, `console`, `graph`, `providers`, and `state` commands as
  debugging tools.
* Solve the most common Google Cloud errors.

---

## 15.1 A troubleshooting mindset

Most Terraform problems fall into four categories. Knowing which one you're
facing tells you where to look.

| Category | Typical symptoms | Where to look |
|---|---|---|
| **Language** (configuration) | Syntax errors, unknown arguments, type mismatches, invalid references | `terraform fmt`, `terraform validate`, the line in the error |
| **State** | Resources Terraform wants to re-create unexpectedly, "already exists" errors, lock errors | `terraform state list/show`, `plan -refresh-only`, Chapter 9 & 11 |
| **Core** | Cycles, crashes, behaviour bugs in Terraform itself (rare) | `TF_LOG_CORE`, crash log, GitHub issues |
| **Provider** | API errors (permissions, quotas, invalid values), authentication | The error text, `TF_LOG_PROVIDER`, cloud audit logs, provider docs |

A simple process:

1. **Read the whole error message.** Terraform errors are usually precise:
   file, line, and a description.
2. **Reproduce** with the smallest command: `validate` before `plan`, `plan`
   before `apply`.
3. **Classify** the error (table above).
4. **Isolate** — comment out unrelated resources, or use `-target` *only* for
   investigation.
5. **Increase visibility** with `terraform console` and logs if needed.

## 15.2 Reading error messages

```console
$ terraform plan
╷
│ Error: Reference to undeclared resource
│
│   on main.tf line 14, in resource "google_compute_subnetwork" "web":
│   14:   network       = google_compute_network.webb.id
│
│ A managed resource "google_compute_network" "webb" has not been declared in
│ the root module.
╵
```

Each diagnostic has:

* **Severity**: `Error` (stops) or `Warning` (continues).
* **Summary**: one line ("Reference to undeclared resource").
* **Location**: file, line, and block.
* **Detail**: often with a suggestion ("Did you mean ...?").

Provider errors include the API's response:

```console
│ Error: Error creating Network: googleapi: Error 403: Required
│ 'compute.networks.create' permission for 'projects/tf-book-fatih-12345/global/networks/web', forbidden
│
│   with google_compute_network.web,
│   on main.tf line 1, in resource "google_compute_network" "web":
```

`googleapi: Error 403` means the API refused the request: a
permissions issue. The HTTP status code is a strong hint (see 15.6).

## 15.3 Verbose logging with `TF_LOG` `[7c]`

When error messages aren't enough, turn on detailed logs with the `TF_LOG`
environment variable:

```console
$ TF_LOG=DEBUG terraform plan
```

Log levels, from most to least verbose:

| Level | Content |
|---|---|
| `TRACE` | Everything, including internal graph walks. Very large. |
| `DEBUG` | Detailed operations, including provider HTTP requests and responses. |
| `INFO` | General informational messages. |
| `WARN` | Warnings. |
| `ERROR` | Errors only. |
| `JSON` | Like `TRACE`, but each line is a JSON object (for tools). |
| `OFF` | Disable (same as unsetting). |

Any value other than these is treated as `TRACE`.

### Writing logs to a file: `TF_LOG_PATH`

Logs go to standard error by default and quickly flood the terminal. Write
them to a file instead:

```console
$ export TF_LOG=DEBUG
$ export TF_LOG_PATH=./terraform-debug.log
$ terraform apply
$ unset TF_LOG TF_LOG_PATH
```

`TF_LOG_PATH` only has an effect when logging is enabled with `TF_LOG` (or
`TF_LOG_CORE`/`TF_LOG_PROVIDER`, below). Without a log level, Terraform creates
the file but writes nothing to it. The file is **appended** to on each run.

### Core vs. provider logs `[7c]`

To focus on one part of the system:

| Variable | Logs from |
|---|---|
| `TF_LOG_CORE=TRACE` | Terraform Core only |
| `TF_LOG_PROVIDER=DEBUG` | Provider plugins only |

```console
$ TF_LOG_PROVIDER=DEBUG terraform apply 2> provider.log
```

For Google Cloud problems, a `DEBUG` log shows the exact HTTP requests sent
to Google APIs and the full responses — invaluable for mysterious API
errors. Use `TF_LOG=DEBUG` for this: the Google provider's request and
response details are missing from a log made with only `TF_LOG_PROVIDER`
set, even at `TRACE`.

```console
$ TF_LOG=DEBUG terraform apply 2> debug.log
```

```
[DEBUG] provider.terraform-provider-google_v8.9.0_x5: ... [DEBUG] Google API Request Details:
---[ REQUEST ]---------------------------------------
POST /compute/v1/projects/tf-book-fatih-12345/global/networks?alt=json HTTP/1.1
...
{
 "autoCreateSubnetworks": false,
 "name": "web"
}
---[ RESPONSE ]--------------------------------------
HTTP/2.0 403 Forbidden
...
```

### When to use verbose logging `[7c]`

* An error message is unclear and you need to see the underlying API call.
* You suspect a **provider bug** and want to include logs in a bug report.
* Terraform **crashes** or hangs.
* You need to understand *why* Terraform made a decision (e.g. graph
  ordering) — `TRACE`.

When **not** to: for everyday work. Logs are huge and slow things down.

> **Security warning:** Debug logs can contain **secrets and access tokens**
> (request bodies, headers). Never paste them publicly without redacting, and
> don't enable `TF_LOG` permanently in CI.

> **Exam tip:** `TF_LOG` enables logging and sets the level; `TF_LOG_PATH`
> sets the output file (a log level must also be set). `TRACE` is the most verbose level.
> `TF_LOG_CORE` and `TF_LOG_PROVIDER` scope logging.

### Crash logs

If Terraform itself panics, it writes a `crash.log` file with the stack
trace. Include it (redacted) when reporting a bug on GitHub. Add `crash.log`
to `.gitignore`.

## 15.4 Built-in debugging tools

| Tool | Use it to |
|---|---|
| `terraform fmt` | Spot syntax problems — it fails on unparseable files. |
| `terraform validate` | Catch type, reference, and argument errors without touching the cloud. |
| `terraform console` | Evaluate expressions, check variable values and functions. |
| `terraform plan` | See the actual intended changes. |
| `terraform show` / `state show` | See what Terraform recorded for a resource. |
| `terraform providers` | Check which providers and versions each module requires. |
| `terraform version` | Check Terraform and provider versions. |
| `terraform graph` | Visualise dependencies, investigate cycles. |
| `terraform plan -refresh-only` | Check for drift. |
| `-json` flags on plan/apply/validate | Machine-readable diagnostics for tools. |

### Example: debugging an expression

```console
$ terraform console
> var.subnets
{
  "europe" = { "region" = "europe-west1" }
}
> keys(var.subnets)[1]
╷
│ Error: Invalid index
│ The given key does not identify an element in this collection value: the
│ given index is greater than or equal to the length of the collection.
╵
```

### Example: dependency cycles

```console
│ Error: Cycle: google_compute_firewall.a, google_compute_firewall.b
```

Two resources reference each other. Break the cycle: usually one of them
should use a static value or a separate resource (e.g. move IAM bindings to
their own resource).

## 15.5 Common errors and fixes

| Error | Cause | Fix |
|---|---|---|
| `Inconsistent dependency lock file` / `Required plugins are not installed` | Provider added or changed, `init` not run | `terraform init` (or `init -upgrade` after constraint changes) |
| `Unsupported Terraform Core version` | CLI outside `required_version` | Install the right version (Chapter 2) |
| `Unsupported argument` / `Missing required argument` | Typo or wrong provider docs version | Check docs for **your** provider version |
| `Reference to undeclared ...` | Typo in a reference, or missing `data.`/`var.`/`local.` prefix | Fix the reference |
| `Invalid for_each argument` ... `known only after apply` | `for_each` uses values that don't exist yet | Use keys known at plan time (variables, literals) |
| `Error acquiring the state lock` | Another run in progress, or a stale lock | Wait; if stale, `terraform force-unlock ID` |
| `Error: ... already exists` (409) | Resource created outside Terraform or lost from state | Import it (Chapter 11) or rename |
| `Backend initialization required` | Backend block changed | `terraform init` (`-migrate-state` / `-reconfigure`) |
| `Cycle:` | Mutual references | Restructure dependencies |

## 15.6 Google Cloud specific errors

| HTTP code / message | Meaning | Typical fix |
|---|---|---|
| `could not find default credentials` | No ADC | `gcloud auth application-default login` |
| **400** `Invalid value` | Bad argument value (name format, CIDR) | Check the value against the API's rules |
| **403** `Permission denied on 'locations/...' (or it may not exist)` | A region or zone that doesn't exist (or that you may not use) | Check the spelling against `gcloud compute regions list` |
| **403** `... has not been used in project ... or it is disabled` | API not enabled | `google_project_service` or `gcloud services enable` |
| **403** `Required '...' permission` / `PERMISSION_DENIED` | Missing IAM role for the identity Terraform uses | Grant the role; check which identity is used (`gcloud auth list`, impersonation) |
| **403** `BILLING_DISABLED` | No billing account linked | Link billing (Chapter 2) |
| **404** `notFound` | Wrong project/region, or the resource was deleted | Check provider defaults; `plan -refresh-only` |
| **409** `alreadyExists` | Name already taken (bucket names are global!) | Pick another name or import |
| **429** / `Quota exceeded` | Hit a quota | Request quota or reduce usage; `-parallelism` lower |
| `Error waiting for ...: timeout` | Long-running operation | Retry; increase `timeouts { }` |
| `The resource ... is not ready` | Eventual consistency (e.g. just-enabled API, new IAM binding) | Retry; add `depends_on` or a `time_sleep` |

**Which identity is Terraform using?** A quick check:

```hcl
data "google_client_openid_userinfo" "me" {}

output "terraform_identity" {
  value = data.google_client_openid_userinfo.me.email
}
```

**Audit logs**: In the Google Cloud console, *Logging → Logs Explorer*, filter
`protoPayload.status.code!=0` to see API calls that failed, which identity
made them, and why.

## Common mistakes and exam tips

* Setting `TF_LOG_PATH` without a log level (`TF_LOG`, `TF_LOG_CORE`, or
  `TF_LOG_PROVIDER`) — the file stays empty.
* Leaving `TF_LOG=TRACE` exported in your shell profile.
* Sharing logs with secrets in them.
* Reading the provider docs for the latest version while using an older
  provider (the docs site has a version selector).
* Using `-target` as a permanent workaround instead of fixing the root cause.

## Summary

* Classify errors as language, state, core, or provider problems.
* Read the full diagnostic; the location and detail usually point at the fix.
* `TF_LOG` (`TRACE`/`DEBUG`/`INFO`/`WARN`/`ERROR`/`JSON`) enables logging;
  `TF_LOG_PATH` writes it to a file; `TF_LOG_CORE`/`TF_LOG_PROVIDER` narrow it.
* Use `validate`, `console`, `graph`, `providers`, and state commands as
  first-line tools.
* HTTP status codes in Google API errors indicate the class of problem.

## Quick check

1. Which environment variable enables Terraform's detailed logs, and which
   is the most verbose level?
2. You set `TF_LOG_PATH=debug.log` but the file stays empty. Why?
3. How do you see only the provider's log messages?
4. A plan fails with `googleapi: Error 403: ... API has not been used in
   project`. What's the fix?
5. Why should you be careful when sharing debug logs?

---

## Hands-on exercise: Fix the broken configuration

**Goal:** Diagnose and fix a configuration with several deliberate bugs
using error messages, `validate`, `console`, and logs.

**Estimated time:** 25 minutes

**Files:** `code/ch15-troubleshooting/exercise/`

### Steps

1. `cd code/ch15-troubleshooting/exercise` and create `terraform.tfvars`.
2. The configuration contains **six bugs** of different kinds. Fix them one at
   a time, using the right tool for each stage:
   1. Run `terraform init`. (Hint: what does the version constraint say?)
   2. Run `terraform fmt`. (A syntax error.)
   3. Run `terraform validate` repeatedly until it succeeds. (Typos and
      references.)
   4. Run `terraform plan`. (A value that's only known after apply.)
   5. Run `terraform apply`. (An API error.)
3. For the API error (the last bug), capture provider logs before fixing it:

   ```console
   $ TF_LOG_PATH=./debug.log terraform apply
   ```

   Look at `debug.log`: it's empty, because no log level was set. Now run
   `TF_LOG=DEBUG TF_LOG_PATH=./debug.log terraform apply` and search the log
   for the failing HTTP request and response:
   `grep -n "HTTP/2.0 4" debug.log`. (With `TF_LOG_PROVIDER=DEBUG` instead,
   the search finds nothing: the Google provider's HTTP details only appear
   with `TF_LOG`.)
4. Write down for each bug: the category (language/state/core/provider), the
   command that revealed it, and the fix. Compare with
   `code/ch15-troubleshooting/solution/BUGS.md`.
5. Delete `debug.log` — it may contain access tokens.

### Expected result

A configuration that applies cleanly, and a list of six bugs with their
categories and fixes.

### Stretch goal

Run `TF_LOG=TRACE terraform plan 2> trace.log` and count the lines
(`wc -l trace.log`). Compare with `DEBUG`. Then delete the files.

### Cleanup

```console
$ terraform destroy
$ rm -f debug.log trace.log
```

---

## Quick check answers

1. `TF_LOG`; `TRACE` is the most verbose.
2. No log level is set. `TF_LOG_PATH` only chooses the file; you also need
   `TF_LOG` (or `TF_LOG_CORE`/`TF_LOG_PROVIDER`).
3. Set `TF_LOG_PROVIDER` (e.g. `TF_LOG_PROVIDER=DEBUG`).
4. Enable the API — with `gcloud services enable` or a
   `google_project_service` resource (plus `depends_on`).
5. They can contain secrets, access tokens, and other sensitive request data.
