# Pinned Versions

Every chapter, code sample, and pipeline in this book uses the versions below.
They were the latest stable releases on **28 October 2026**. Pinning versions
means the examples behave the same way for you as they did for the author, even
after newer releases come out.

| Tool | Pinned version | Where it is pinned |
|---|---|---|
| Terraform CLI | **1.17.0** | `required_version = "~> 1.17.0"` in every `versions.tf`; CI installs exactly `1.17.0` |
| Provider `hashicorp/google` | **8.9.0** | `version = "8.9.0"` in `required_providers` |
| Provider `hashicorp/google-beta` | **8.9.0** | `version = "8.9.0"` (Chapter 4 only) |
| Provider `hashicorp/random` | **3.9.1** | `version = "3.9.1"` |
| Google Cloud CLI (`gcloud`) | **591.0.0** | Chapter 2 install instructions; Cloud Build image `gcr.io/google.com/cloudsdktool/google-cloud-cli:591.0.0-debian_component_based`; GitHub Actions `setup-gcloud` input `version: 591.0.0` |
| TFLint | **0.65.0** | Chapter 19, CI pipelines |
| TFLint Google ruleset | **0.41.0** | `.tflint.hcl` |
| pre-commit-terraform hooks | **v1.109.3** | `.pre-commit-config.yaml` |
| GitHub Action `actions/checkout` | **v7.0.1** | Chapter 21 workflows |
| GitHub Action `hashicorp/setup-terraform` | **v4.0.1** | Chapter 21 workflows |
| GitHub Action `google-github-actions/auth` | **v3.0.0** | Chapter 21 workflows |
| GitHub Action `google-github-actions/setup-gcloud` | **v3.0.1** | Chapter 21 workflows |
| Container image `hashicorp/terraform` | **1.17.0** | Chapter 22 Cloud Build steps |
| Container image `ghcr.io/terraform-linters/tflint` | **v0.65.0** | Chapter 22 Cloud Build steps |
| `gcloud` component `terraform-tools` | **0.12.3** | Chapter 20 (`gcloud beta terraform vet`) |
| Provider `hashicorp/http` | **3.6.3** | Chapters 8 and 19 |
| Provider `hashicorp/tfe` | **0.82.0** | Chapter 16 |
| Provider `hashicorp/vault` | **5.13.0** | Chapter 14 (example) |
| Module `terraform-google-modules/network/google` | **18.3.1** | Chapter 12 |
| Module `terraform-google-modules/cloud-storage/google` | **12.4.1** | Chapter 12 |
| actionlint | **1.7.12** | Optional workflow linting |

## Why `~> 1.17.0` for Terraform but an exact pin for providers?

* `required_version = "~> 1.17.0"` allows Terraform **1.17.x** patch releases
  (bug and security fixes) but blocks 1.18, which might change behaviour.
* Providers are pinned exactly (`"8.9.0"`) so the code always matches the
  documentation used to write it. The dependency lock file
  (`.terraform.lock.hcl`) additionally records checksums of the provider
  binaries. Chapter 4 explains both mechanisms and when to loosen them.

## A note about the certification exam

The Terraform Associate **004** exam was written against an earlier Terraform
release (1.12). Everything the exam tests still works the same way in 1.17.
Where the book uses a newer feature, the text marks it with
**"Newer than the exam"** so you know it is good practice but not exam material.

## Upgrading later

When you want to move to newer versions:

1. Change the version numbers in `versions.tf` (or in this table and then in the code).
2. Run `terraform init -upgrade` to download the new provider and update the lock file.
3. Run `terraform plan` and read the provider's upgrade guide for any breaking changes.
4. Commit the updated `.terraform.lock.hcl`.
