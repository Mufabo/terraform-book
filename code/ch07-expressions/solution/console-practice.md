# terraform console practice

Run `terraform console` in this folder (after `terraform init` and creating
`terraform.tfvars`). Predict each result, then check.

```hcl
upper(var.environment)
format("vm-%03d", 7)
[for z in ["b", "c", "d"] : "${var.region}-${z}"]
{ for name, cfg in var.buckets : name => cfg.storage_class }
[for p in [22, 80, 443] : p if p != 22]
keys(var.subnets)
sort(keys(var.subnets))
cidrsubnet(var.base_cidr, 8, 0)
cidrsubnet(var.base_cidr, 8, 1)
cidrhost("10.0.1.0/24", 10)
var.firewall_rules[*].protocol
merge({ a = 1 }, { b = 2 }, { a = 3 })
lookup({ dev = "e2-micro" }, "prod", "e2-small")
try(var.buckets["missing"].location, "none")
var.enable_ssh ? 1 : 0
jsonencode({ name = "web", ports = [80, 443] })
```
