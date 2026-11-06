# Policy library for `gcloud beta terraform vet`

```
policy-library/
├── lib/                       # shared Rego helpers (empty here, but must exist)
└── policies/
    ├── templates/             # ConstraintTemplates: the rules, written in Rego
    └── constraints/           # Constraints: turn a template on, with parameters
```

| Constraint | Template | Type | Checks |
|---|---|---|---|
| `storage-location-europe` | `TFStorageBucketLocationAllowlistConstraintV1` | Terraform (plan) | Buckets are in allowed European locations |
| `storage-public-access-prevention` | `TFStorageBucketPublicAccessPreventionConstraintV1` | Terraform (plan) | Buckets enforce public access prevention |
| `required-labels` | `TFRequiredLabelsConstraintV1` | Terraform (plan) | Buckets and Cloud Run services have `environment` and `managed_by` labels |
| `no-public-cloud-run` | `GCPIAMBannedMembersConstraintV1` | CAI (asset) | No `allUsers`/`allAuthenticatedUsers` in Cloud Run IAM policies |

Run it:

```console
$ terraform plan -out=tfplan
$ terraform show -json tfplan > tfplan.json
$ gcloud beta terraform vet tfplan.json --policy-library=./policy-library
```

Exit codes: `0` no violations, `2` violations found, `1` error.
