#!/usr/bin/env bash
# Runs Terraform for one environment and makes sure the backend and the
# tfvars file always belong together.
#
#   ./tf.sh dev plan
#   ./tf.sh prod apply
set -euo pipefail

usage="usage: TF_STATE_BUCKET=<bucket> ./tf.sh <dev|prod> <terraform command> [args]"
env="${1:?$usage}"
command="${2:?$usage}"
shift 2

if [ ! -f "${env}.tfvars" ]; then
  echo "Unknown environment '${env}': ${env}.tfvars not found." >&2
  exit 1
fi
: "${TF_STATE_BUCKET:?$usage}"

# -reconfigure: point this working directory at the environment's state
# without offering to copy the state of the previously used environment.
terraform init -input=false -reconfigure \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="prefix=ch18c/${env}" >/dev/null

terraform "$command" -var-file="${env}.tfvars" "$@"
