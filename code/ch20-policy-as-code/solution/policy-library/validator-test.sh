#!/usr/bin/env bash
# Offline smoke test for the Terraform-based (plan) constraints, using the
# terraform-tools binary that `gcloud beta terraform vet` runs under the hood.
# It doesn't need Google Cloud credentials.
#   usage: ./validator-test.sh path/to/tfplan.json
set -euo pipefail
# Ask gcloud where it is installed; `command -v gcloud` may be a symlink.
TOOLS="$(gcloud info --format='value(installation.sdk_root)')/bin/terraform-tools"
"$TOOLS" validate-tfplan "${1:?plan json}" --policy-library="$(dirname "$0")"
