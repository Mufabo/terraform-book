#!/usr/bin/env bash
# Creates two buckets *outside* Terraform, to practise importing them.
set -euo pipefail
PROJECT_ID="${1:?usage: ./create-legacy.sh PROJECT_ID}"

gcloud storage buckets create "gs://${PROJECT_ID}-legacy-site" \
  --project="$PROJECT_ID" --location=europe-west1 \
  --uniform-bucket-level-access --default-storage-class=STANDARD
gcloud storage buckets update "gs://${PROJECT_ID}-legacy-site" --update-labels=team=web

gcloud storage buckets create "gs://${PROJECT_ID}-legacy-media" \
  --project="$PROJECT_ID" --location=europe-west1 \
  --uniform-bucket-level-access --default-storage-class=NEARLINE

echo "Created gs://${PROJECT_ID}-legacy-site and gs://${PROJECT_ID}-legacy-media"
