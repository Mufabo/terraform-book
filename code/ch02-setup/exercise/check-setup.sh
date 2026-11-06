#!/usr/bin/env bash
# Checks that the tools and settings from Chapter 2 are in place.
set -u

EXPECTED_TF="1.17.0"
ok()   { printf '  [ OK ]    %s\n' "$1"; }
bad()  { printf '  [ %s ] %s\n' "$2" "$1"; FAILED=1; }
FAILED=0

echo "Checking your Terraform book setup..."

if command -v terraform >/dev/null 2>&1; then
  tf_version=$(terraform version -json | sed -n 's/.*"terraform_version": *"\([^"]*\)".*/\1/p')
  if [ "$tf_version" = "$EXPECTED_TF" ]; then
    ok "Terraform $tf_version"
  else
    bad "Terraform $tf_version found, expected $EXPECTED_TF" "WRONG  "
  fi
else
  bad "terraform is not on your PATH" "MISSING"
fi

if command -v gcloud >/dev/null 2>&1; then
  ok "gcloud $(gcloud version 2>/dev/null | head -n1 | awk '{print $4}')"
  project=$(gcloud config get-value project 2>/dev/null)
  if [ -n "$project" ]; then
    ok "gcloud project is set to: $project"
    billing=$(gcloud billing projects describe "$project" --format='value(billingEnabled)' 2>/dev/null)
    if [ "$billing" = "True" ]; then ok "Billing is enabled"; else bad "Billing is not enabled for $project" "MISSING"; fi
  else
    bad "No default project. Run: gcloud config set project PROJECT_ID" "MISSING"
  fi
  if gcloud auth application-default print-access-token >/dev/null 2>&1; then
    ok "Application Default Credentials work"
  else
    bad "No ADC. Run: gcloud auth application-default login" "MISSING"
  fi
else
  bad "gcloud is not on your PATH" "MISSING"
fi

if command -v git >/dev/null 2>&1; then ok "git $(git --version | awk '{print $3}')"; else bad "git is not installed" "MISSING"; fi

echo
if [ "$FAILED" -eq 0 ]; then echo "All checks passed. You are ready!"; else echo "Some checks failed. See Chapter 2."; exit 1; fi
