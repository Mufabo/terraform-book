# secure-bucket

Creates a Cloud Storage bucket with secure defaults:

* uniform bucket-level access and public access prevention
* object versioning
* optional age-based deletion (`retention_days`)
* optional read access for a set of IAM members (`readers`)

## Usage

```hcl
module "logs" {
  source  = "app.terraform.io/acme/secure-bucket/google"
  version = "~> 1.0"

  project_id     = var.project_id
  name           = "${var.project_id}-logs"
  retention_days = 30
  readers        = ["group:auditors@example.com"]
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | — | Project in which to create the bucket. |
| `name` | `string` | — | Globally unique bucket name. |
| `location` | `string` | `"EU"` | Bucket location. |
| `retention_days` | `number` | `0` | Delete objects older than this many days. 0 disables. |
| `readers` | `set(string)` | `[]` | IAM members granted `roles/storage.objectViewer`. |
| `labels` | `map(string)` | `{}` | Labels added to the bucket. |
| `force_destroy` | `bool` | `false` | Allow deleting a non-empty bucket. |

## Outputs

| Name | Description |
|---|---|
| `name` | The bucket name. |
| `url` | The gs:// URL of the bucket. |
| `self_link` | The bucket's self link. |
