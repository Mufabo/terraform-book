#!/usr/bin/env bash
# Checks that the tools and settings from Chapter 2 are in place.
set -u

EXPECTED_TF="1.17"          # any 1.17.x patch release matches "~> 1.17.0"
EXPECTED_GCLOUD="591.0.0"
REQUIRED_APIS="compute.googleapis.com storage.googleapis.com iam.googleapis.com
cloudresourcemanager.googleapis.com secretmanager.googleapis.com run.googleapis.com
artifactregistry.googleapis.com cloudbuild.googleapis.com iamcredentials.googleapis.com
sts.googleapis.com"

ok()   { printf '  [ OK ]      %s\n' "$1"; }
bad()  { printf '  [ %s ] %s\n' "$2" "$1"; FAILED=1; }
warn() { printf '  [ WARN ]    %s\n' "$1"; }
FAILED=0

echo "Checking your Terraform book setup..."

if command -v terraform >/dev/null 2>&1; then
  tf_version=$(terraform version -json | sed -n 's/.*"terraform_version": *"\([^"]*\)".*/\1/p')
  case "$tf_version" in
    "$EXPECTED_TF".*) ok "Terraform $tf_version" ;;
    *) bad "Terraform $tf_version found, expected $EXPECTED_TF.x" "WRONG  " ;;
  esac
else
  bad "terraform is not on your PATH" "MISSING"
fi

if command -v gcloud >/dev/null 2>&1; then
  gcloud_version=$(gcloud version 2>/dev/null | head -n1 | awk '{print $4}')
  if [ "$gcloud_version" = "$EXPECTED_GCLOUD" ]; then
    ok "gcloud $gcloud_version"
  else
    warn "gcloud $gcloud_version found, the book was tested with $EXPECTED_GCLOUD"
  fi

  project=$(gcloud config get-value project 2>/dev/null)
  if [ -n "$project" ]; then
    ok "gcloud project is set to: $project"
    billing=$(gcloud billing projects describe "$project" --format='value(billingEnabled)' 2>/dev/null)
    if [ "$billing" = "True" ]; then ok "Billing is enabled"; else bad "Billing is not enabled for $project" "MISSING"; fi

    enabled=$(gcloud services list --enabled --project "$project" --format='value(config.name)' 2>/dev/null)
    missing=""
    for api in $REQUIRED_APIS; do
      printf '%s\n' "$enabled" | grep -qx "$api" || missing="$missing $api"
    done
    if [ -z "$missing" ]; then ok "All required APIs are enabled"; else bad "APIs not enabled (section 2.5):$missing" "MISSING"; fi
  else
    bad "No default project. Run: gcloud config set project PROJECT_ID" "MISSING"
  fi

  if gcloud auth application-default print-access-token >/dev/null 2>&1; then
    ok "Application Default Credentials work"
    adc_file="${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}/application_default_credentials.json"
    quota=$(sed -n 's/.*"quota_project_id": *"\([^"]*\)".*/\1/p' "$adc_file" 2>/dev/null)
    if [ -z "$quota" ]; then
      warn "ADC has no quota project. Run: gcloud auth application-default set-quota-project PROJECT_ID"
    elif [ -n "$project" ] && [ "$quota" != "$project" ]; then
      warn "ADC quota project is $quota, but the gcloud project is $project"
    else
      ok "ADC quota project is set to: $quota"
    fi
  else
    bad "No ADC. Run: gcloud auth application-default login" "MISSING"
  fi
else
  bad "gcloud is not on your PATH" "MISSING"
fi

if command -v git >/dev/null 2>&1; then ok "git $(git --version | awk '{print $3}')"; else bad "git is not installed" "MISSING"; fi

echo
if [ "$FAILED" -eq 0 ]; then echo "All checks passed. You are ready!"; else echo "Some checks failed. See Chapter 2."; exit 1; fi
