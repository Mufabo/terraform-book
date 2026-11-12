# Chapter 8 challenge: what each command should show

| Command | Result |
|---|---|
| `terraform plan -var location=US` | **Error** from the `location` validation. |
| `terraform plan -var location=europe-west4` | Passes: the validation compares in upper case. |
| `terraform plan -var retention_days=0` | **Error**: must be between 1 and 365. |
| `terraform plan -var retention_days=7.5` | **Error**: must be a whole number. |
| `terraform plan -var environment=prod` | **Error** from the precondition: prod needs versioning (plus the check block's warning). |
| `terraform plan -var environment=prod -var versioning=true` | Plan succeeds, with a **warning** from the check block (30 days is less than 90). |
| `terraform plan -var environment=prod -var versioning=true -var retention_days=120` | Clean plan. |

Why each mechanism:

* `location` and `retention_days` are rules about **one input** → `validation`.
* "prod needs versioning" combines **two inputs** → `precondition` on the
  resource that relies on it. (Since Terraform 1.9 a validation may also
  refer to another variable, so a `validation` on `versioning` would work
  too. The precondition keeps the rule next to the bucket it protects.)
* "public access prevention is enforced" is a promise about the **result** →
  `postcondition`.
* The 90-day guideline shouldn't stop a deployment → `check`, which only
  warns.
* The audit tool owns the `last_audit` label → `ignore_changes`.
