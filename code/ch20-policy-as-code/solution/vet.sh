#!/usr/bin/env bash
# Plans a Terraform configuration and validates the plan against a policy library.
# usage: ./vet.sh [CONFIG_DIR] [POLICY_LIBRARY] [extra terraform plan args...]
set -uo pipefail
CONFIG_DIR="${1:-sample}"
POLICY_LIBRARY="$(cd "${2:-policy-library}" && pwd)"
shift $(( $# > 2 ? 2 : $# ))

cd "$CONFIG_DIR" || exit 1
terraform plan -input=false -out=tfplan "$@" || exit 1
terraform show -json tfplan > tfplan.json

gcloud beta terraform vet tfplan.json --policy-library="$POLICY_LIBRARY" --format=json
status=$?
rm -f tfplan tfplan.json

case $status in
  0) echo "✔ No policy violations." ;;
  2) echo "✘ Policy violations found." ;;
  *) echo "✘ terraform vet failed with exit code $status." ;;
esac
exit $status
