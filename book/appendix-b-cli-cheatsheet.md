# Appendix B — CLI Cheat Sheet

All commands for Terraform 1.17. Commands marked ✎ can change
infrastructure or state.

## Core workflow

| Command | Purpose |
|---|---|
| `terraform init` | Initialise: backend, providers (+ lock file), modules |
| `terraform init -upgrade` | Upgrade providers and modules within constraints |
| `terraform init -migrate-state` | Move state to a newly configured backend |
| `terraform init -reconfigure` | Use new backend settings without migrating |
| `terraform init -backend-config=FILE` | Partial backend configuration |
| `terraform init -backend=false` | Skip backend (e.g. for validation in CI) |
| `terraform fmt [-recursive] [-check] [-diff]` | Format code |
| `terraform validate` | Check syntax and consistency (no API calls) |
| `terraform plan` | Preview changes |
| `terraform plan -out=tfplan` | Save a plan |
| `terraform plan -destroy` | Preview a destroy |
| `terraform plan -refresh-only` | Show drift only |
| `terraform plan -detailed-exitcode` | Exit 0 = no changes, 1 = error, 2 = changes |
| ✎ `terraform apply` | Plan and apply (asks for `yes`) |
| ✎ `terraform apply tfplan` | Apply a saved plan (no prompt) |
| ✎ `terraform apply -auto-approve` | Apply without prompt |
| ✎ `terraform apply -refresh-only` | Accept drift into state |
| ✎ `terraform apply -replace=ADDR` | Force re-creation of a resource |
| ✎ `terraform destroy` | Destroy everything in the configuration (= `apply -destroy`) |

Common plan/apply flags: `-var 'k=v'`, `-var-file=FILE`, `-target=ADDR`
(emergencies only), `-parallelism=N` (default 10), `-lock-timeout=60s`,
`-lock=false` (avoid), `-refresh=false`, `-input=false`, `-no-color`,
`-json`.

## Inspecting

| Command | Purpose |
|---|---|
| `terraform show [tfplan]` | Show state or a saved plan |
| `terraform show -json tfplan` | Plan as JSON (policy tools) |
| `terraform output [NAME]` | Show outputs |
| `terraform output -raw NAME` / `-json` | Outputs for scripts |
| `terraform state list [ADDR]` | List resources in state |
| `terraform state show ADDR` | Show one resource's attributes |
| `terraform state pull` | Print raw state JSON |
| `terraform console` | Evaluate expressions interactively |
| `terraform graph` | Dependency graph in DOT format |
| `terraform providers` | Required providers per module |
| `terraform providers lock -platform=...` | Add platform checksums to the lock file |
| `terraform version` | Terraform and provider versions |

## Changing state

| Command | Purpose | Declarative alternative |
|---|---|---|
| ✎ `terraform state mv SRC DST` | Rename/move in state | `moved` block |
| ✎ `terraform state rm ADDR` | Forget a resource (keeps it in the cloud) | `removed` block, `destroy = false` |
| ✎ `terraform import ADDR ID` | Adopt an existing resource | `import` block |
| ✎ `terraform state push FILE` | Overwrite state (disaster recovery) | — |
| ✎ `terraform force-unlock LOCK_ID` | Remove a stale lock | — |
| `terraform plan -generate-config-out=FILE` | Write config for `import` blocks | — |
| ✎ `terraform taint` / `refresh` | Deprecated | `-replace`, `-refresh-only` |

## Workspaces (CLI)

| Command | Purpose |
|---|---|
| `terraform workspace list` | List workspaces |
| `terraform workspace show` | Current workspace |
| `terraform workspace new NAME` | Create and switch |
| `terraform workspace select NAME` | Switch |
| `terraform workspace delete NAME` | Delete (not `default`) |

In configuration: `terraform.workspace`.

## Testing

| Command | Purpose |
|---|---|
| `terraform test` | Run all `*.tftest.hcl` files |
| `terraform test -filter=tests/unit.tftest.hcl` | Run selected files |
| `terraform test -verbose` | Show plans/state of each run |
| `terraform test -junit-xml=FILE` | Write JUnit results |

## HCP Terraform

| Command | Purpose |
|---|---|
| `terraform login [HOST]` | Get an API token |
| `terraform logout [HOST]` | Remove the token |

Environment variables: `TF_TOKEN_app_terraform_io`, `TF_CLOUD_ORGANIZATION`,
`TF_WORKSPACE`, `TF_CLOUD_PROJECT`, `TF_CLOUD_HOSTNAME`.

## Logging

| Variable | Meaning |
|---|---|
| `TF_LOG=TRACE\|DEBUG\|INFO\|WARN\|ERROR\|JSON\|OFF` | Enable logs at a level |
| `TF_LOG_PATH=file.log` | Write logs to a file (needs a log level) |
| `TF_LOG_CORE=...` / `TF_LOG_PROVIDER=...` | Core-only / provider-only logs |

## Other useful environment variables

| Variable | Meaning |
|---|---|
| `TF_VAR_name` | Set input variable `name` |
| `TF_IN_AUTOMATION=true` | Less interactive output in CI |
| `TF_INPUT=false` | Never prompt for input |
| `TF_PLUGIN_CACHE_DIR` | Shared provider cache |
| `TF_DATA_DIR` | Location of `.terraform` |
| `TF_CLI_ARGS_plan="-parallelism=5"` | Default extra arguments per command |

## Variable precedence (lowest → highest)

1. `default` in the `variable` block
2. `TF_VAR_name` environment variables
3. `terraform.tfvars`
4. `terraform.tfvars.json`
5. `*.auto.tfvars` / `*.auto.tfvars.json` (alphabetical)
6. `-var` / `-var-file` on the command line (in order given)

## Version constraints

| Constraint | Allows |
|---|---|
| `"1.2.3"` / `"= 1.2.3"` | exactly 1.2.3 |
| `">= 1.2, < 2.0"` | 1.2 up to (not including) 2.0 |
| `"~> 1.2.0"` | `>= 1.2.0, < 1.3.0` |
| `"~> 1.2"` | `>= 1.2, < 2.0` |
| `"!= 1.2.5"` | anything except 1.2.5 |

## Plan symbols

| Symbol | Action |
|---|---|
| `+` | create |
| `-` | destroy |
| `~` | update in place |
| `-/+` | destroy, then create (replace) |
| `+/-` | create, then destroy (`create_before_destroy`) |
| `<=` | read data source |

## Google Cloud companions

| Command | Purpose |
|---|---|
| `gcloud auth application-default login` | Credentials for Terraform (ADC) |
| `gcloud auth application-default set-quota-project ID` | Quota project for ADC |
| `gcloud services enable SERVICE` | Enable an API |
| `gcloud components install terraform-tools` | Install `terraform vet` |
| `gcloud beta terraform vet tfplan.json --policy-library=DIR` | Policy check (exit 2 = violations) |
| `gcloud storage ls -r gs://BUCKET/` | Inspect a state bucket |
