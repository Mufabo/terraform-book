# simple-network

A custom-mode VPC network with any number of subnets (Private Google Access
on) and an optional firewall rule for SSH through Identity-Aware Proxy.

```hcl
module "network" {
  source = "./modules/simple-network"

  project_id = var.project_id
  name       = "dev"

  subnets = {
    app = { region = "europe-west1", cidr = "10.80.0.0/24" }
  }
}
```

| Input | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | (required) | Project in which to create the network. |
| `name` | `string` | (required) | Network name and prefix of the other names. |
| `subnets` | `map(object({ region, cidr }))` | (required) | Subnets, keyed by short name. |
| `enable_iap_ssh` | `bool` | `false` | Create the IAP SSH firewall rule. |

| Output | Description |
|---|---|
| `network_id` | ID of the network. |
| `subnet_ids` | Map of short name to subnet ID. |
| `ssh_tag` | Network tag for IAP SSH, or `null`. |
