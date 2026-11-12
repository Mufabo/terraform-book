# Chapter 14 challenge: two secrets that never reach state

**Supplying the token.** Use an environment variable, so the value is neither
in a file nor in your shell history:

```console
$ read -rs TF_VAR_partner_token && export TF_VAR_partner_token
```

**Proving it.** With the token `demo-token-123`:

```console
$ terraform plan -out=tfplan
$ terraform show -json tfplan | grep -c "demo-token-123"
0
$ terraform apply tfplan
$ terraform state pull | grep -c "demo-token-123"
0
$ gcloud secrets versions access latest --secret=ch14c-partner-token
demo-token-123
```

`terraform apply tfplan` only works while `TF_VAR_partner_token` is still
set: an ephemeral variable isn't saved in the plan file, so Terraform asks
for it again at apply time. That is the point of the feature.

**Rotating.** Changing only `TF_VAR_partner_token` changes nothing: Terraform
doesn't store the old value, so it can't see a difference. Set
`-var partner_token_version=2` as well, and the version is replaced.

**Why a variable for one secret and `ephemeral "random_password"` for the
other?** The partner issues the token, so it has to come from outside. The
signing key only has to be random, so Terraform can generate it and no human
ever sees it.

**Why `for_each` over a map with fixed keys for the IAM members?** The keys
(`partner_token`, `signing_key`) are known at plan time; the secret IDs are
the values, which may be unknown until apply.

Cleanup: `terraform destroy` (the token must still be set, or pass any value:
it isn't used for destroying).
