# Appendix D — Cost Estimate

How much will working through every exercise in this book cost? If you
destroy your resources at the end of each exercise, the answer is **well under
US$1 in total**, and usually **nothing at all**: new Google Cloud customers get
free-trial credits (US$300 for 90 days at the time of writing), and almost
everything the exercises create fits in Google Cloud's always-free tier.

This appendix shows where that number comes from, and what *can* cost money
if you forget to clean up.

> **Cost note:** All prices are approximate list prices in US dollars for the
> book's default region (`europe-west1`, buckets in `EU`) at the time of
> writing. Prices and free-tier limits change, and your billing currency may
> differ. Check the
> [Google Cloud pricing calculator](https://cloud.google.com/products/calculator)
> and the [free tier page](https://cloud.google.com/free) for current figures.

## What is billed, and at what rate

| Resource | Used in chapters | Rate | Free tier |
|---|---|---|---|
| `e2-micro` VM | 5, 8, 10, 12 | ≈ $0.009 per hour | One per month, but only in `us-west1`, `us-central1`, `us-east1` — **not** `europe-west1` |
| Boot disk (10 GB standard persistent disk) | 5, 8, 10, 12 | ≈ $0.04 per GB-month (≈ $0.0006 per hour) | 30 GB-month in the same US regions |
| External IPv4 address on a VM | 5, 8, 12 | $0.005 per hour | None |
| Cloud Storage (Standard, `EU`) | Most chapters | ≈ $0.026 per GB-month, plus fractions of a cent per 1,000 operations | 5 GB-month, US regions only |
| Cloud Run (`min_instances = 0`) | 14, 18–22 | Billed only while handling requests | 180,000 vCPU-seconds, 360,000 GiB-seconds and 2 million requests per month |
| Secret Manager | 14, 22 | $0.06 per active secret version per month; $0.03 per 10,000 accesses | 6 active versions and 10,000 accesses per month |
| Cloud Logging | All | $0.50 per GiB ingested | 50 GiB per project per month |
| VPC networks, subnets, firewall rules | 5–7, 10, 12, 15, 22 | Free | — |
| IAM, service accounts, Workload Identity Federation | 14, 16, 18–22 | Free | — |
| Enabling APIs, billing budgets | 2 and most chapters | Free | — |

Services outside Google Cloud:

| Service | Used in chapters | Cost |
|---|---|---|
| HCP Terraform | 16, 17 | Free tier is enough for the exercises. |
| GitHub Actions | 21, 22 | Free for public repositories; private repositories on the Free plan get 2,000 minutes per month. |

The Cloud Run services run Google's public sample image
(`us-docker.pkg.dev/cloudrun/container/hello`), so there is no Artifact
Registry storage to pay for. Policy checks with `gcloud beta terraform vet`
(Chapter 20) and the mocked unit tests (Chapter 19) create no resources.

## Estimate per chapter

Assumptions: each exercise's resources exist for **two hours** (the exercise
plus a generous margin), you destroy them afterwards, and you are outside the
free trial. The "billable" column lists only resources that cost anything.

| Chapter | Billable resources | Estimated cost |
|---|---|---|
| 1 | None (no cloud resources) | $0.00 |
| 2 | Project, API, budget | $0.00 |
| 3, 4 | Storage buckets | < $0.01 |
| 5 | `e2-micro` VM + disk + external IP | ≈ $0.03 |
| 6, 7 | Bucket; network resources are free | < $0.01 |
| 8 | `e2-micro` VM + disk + external IP, bucket | ≈ $0.03 |
| 9 | Buckets | < $0.01 |
| 10 | State bucket, `e2-micro` VM + disk (IAP, no external IP) | ≈ $0.02 |
| 11 | Bucket and one object | < $0.01 |
| 12 | `e2-micro` VM + disk + external IP, buckets | ≈ $0.03 |
| 13 | Buckets | < $0.01 |
| 14 | Cloud Run, two secrets (one version) | $0.00 (free tier) |
| 15 | Bucket; network resources are free | < $0.01 |
| 16, 17 | Buckets; HCP Terraform free tier | < $0.01 |
| 18 | Cloud Run and buckets in dev and prod | < $0.01 |
| 19 | Integration test creates and destroys Cloud Run and a bucket | < $0.01 |
| 20 | None (plan and `vet` only) | $0.00 |
| 21 | State bucket, Cloud Run in dev and prod, GitHub Actions | < $0.01 |
| 22 | State bucket, Cloud Run, secrets, GitHub Actions | < $0.01 (free tier) |
| **Total** | | **≈ $0.15–0.25** |

The optional challenges use the same kinds of resources and add a few cents
at most; only Chapter 5's creates VMs (two of them). Almost the whole total
comes from the four chapters with a VM. If you work
through the book during the free trial, it's covered by the credits.

> **Tip:** If you want to avoid even the VM cost, you can run Chapters 5, 8,
> 10 and 12 in `us-central1` instead of `europe-west1`: the first `e2-micro`
> VM and 30 GB of standard disk per month are free there. The external IP
> address is still billed.

## What a forgotten resource costs

The real risk is not the exercises themselves but something left running
after them. Approximate monthly cost of common leftovers:

| Left running for a month | Approximate cost |
|---|---|
| `e2-micro` VM with a 10 GB disk and an external IP (`europe-west1`) | ≈ $10–11 (VM ≈ $6.50, IP ≈ $3.65, disk ≈ $0.40) |
| The same VM without an external IP (Chapter 10) | ≈ $7 |
| A stopped VM (disk and any reserved static IP still billed) | ≈ $0.40 for the disk, more with a static IP |
| A larger VM (e.g. `e2-small` or `e2-medium`, if you apply Chapter 8 with `environment = "prod"`) | ≈ $13–25 plus disk and IP |
| Cloud Run service with `min_instances = 0` | $0 while idle |
| Cloud Run service changed to `min_instances = 1` | Several dollars to tens of dollars, depending on CPU and memory |
| Storage buckets from the exercises (KB to MB of data) | < $0.01 |
| A secret with one version beyond the free six | $0.06 |

Two habits keep this at zero:

* Keep the **budget alert** from Chapter 2. A budget of 10 in your billing
  currency fires long before a forgotten VM becomes expensive.
* After each exercise, run `terraform destroy` and, now and then, the
  leftover checks in Appendix C. When you finish the book, deleting the whole
  project (also in Appendix C) is the surest way to stop all charges.
