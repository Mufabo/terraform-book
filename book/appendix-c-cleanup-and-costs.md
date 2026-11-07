# Appendix C — Cleanup and Costs

## What the exercises cost

If you destroy your resources at the end of each exercise, the whole book
costs well under US$1 — usually nothing, thanks to the free tier and the
free-trial credits. Appendix D breaks the estimate down by resource and by
chapter, and lists what forgotten resources cost per month.

## Always destroy

At the end of every exercise:

```console
$ terraform destroy
```

If `destroy` fails:

| Error | Fix |
|---|---|
| `prevent_destroy` | Remove the `prevent_destroy` line, apply, then destroy. |
| `deletion_protection` (Cloud Run, VM, Cloud SQL) | Set `deletion_protection = false`, `terraform apply`, then destroy. |
| Bucket not empty | Set `force_destroy = true` and apply, or empty it with `gcloud storage rm -r gs://BUCKET/**`. |
| Resource in use (e.g. network used by a VM from another configuration) | Destroy the dependent configuration first (reverse order of creation). |
| Lost state | Delete the resources by hand (see below), or import them and destroy. |

## Find leftovers

Run these commands to list anything you might have forgotten:

```console
$ gcloud compute instances list
$ gcloud compute addresses list
$ gcloud compute networks list            # "default" is created by Google — keep it
$ gcloud compute firewall-rules list
$ gcloud storage buckets list --format="value(name)"
$ gcloud run services list
$ gcloud secrets list
$ gcloud iam service-accounts list
$ gcloud iam workload-identity-pools list --location=global
```

Or look at **all** resources in the project at once with Cloud Asset
Inventory:

```console
$ gcloud asset search-all-resources --scope=projects/$PROJECT_ID \
    --format="table(assetType,name)"
```

Delete leftovers individually, e.g.:

```console
$ gcloud compute instances delete NAME --zone=ZONE
$ gcloud storage rm -r gs://BUCKET
$ gcloud run services delete NAME --region=REGION
$ gcloud secrets delete NAME
```

Note: deleted Workload Identity pools and service accounts are kept in a
"soft-deleted" state for 30 days, during which their IDs can't be reused. If
you re-run a bootstrap configuration quickly after destroying it, either
undelete them (`gcloud iam workload-identity-pools undelete`) or pick new IDs.

## The nuclear option: delete the project

The cleanest way to remove everything is to shut down the learning project:

```console
$ gcloud projects delete $PROJECT_ID
```

All resources in the project stop immediately and are deleted. The project
can be restored within 30 days (`gcloud projects undelete`). Billing stops
for the project's resources once it's shut down.

## HCP Terraform and GitHub

* HCP Terraform: delete workspaces (*Settings → Destruction and Deletion*)
  after destroying their resources, then policy sets and registry modules.
  The organisation can be deleted under *Settings → General*.
* GitHub: archive or delete the practice repository; remove repository
  variables and environments if you keep it.

## Budget alerts

Keep the budget alert from Chapter 2 in place until you've confirmed your bill
is zero for a full month after finishing the book.
