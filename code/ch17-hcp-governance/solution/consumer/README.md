# ch17 consumer — workspace variables

Set these in the `ch17-consumer` workspace (or a variable set on the
`terraform-book` project):

| Category | Key | Value |
|---|---|---|
| Terraform | `project_id` | your project ID |
| Environment | `TFC_GCP_PROVIDER_AUTH` | `true` |
| Environment | `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL` | output `service_account_email` from `wif/` |
| Environment | `TFC_GCP_WORKLOAD_PROVIDER_NAME` | output `workload_provider_name` from `wif/` |
