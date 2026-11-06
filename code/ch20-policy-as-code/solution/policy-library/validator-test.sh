#!/usr/bin/env bash
# Offline smoke test for the Terraform-based (plan) constraints, using the
# terraform-tools binary that `gcloud beta terraform vet` runs under the hood.
# It doesn't need Google Cloud credentials.
#   usage: ./validator-test.sh path/to/tfplan.json
set -euo pipefail
TOOLS="$(dirname "$(command -v gcloud)")/terraform-tools"
"$TOOLS" validate-tfplan "${1:?plan json}" --policy-library="$(dirname "$0")"
