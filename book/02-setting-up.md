# Chapter 2 — Setting Up Your Environment

## Learning objectives

By the end of this lesson you will be able to:

* Install a **specific, pinned version** of Terraform (1.17.0) on Windows,
  macOS, or Linux.
* Install and initialise the Google Cloud CLI (`gcloud`).
* Create a Google Cloud project, link billing, and set a **budget alert**.
* Authenticate Terraform to Google Cloud using **Application Default
  Credentials (ADC)**.
* Enable the Google Cloud APIs used in this book.
* Set up a code editor with Terraform support.

> This chapter is mostly setup. It is not directly tested on the exam, but every
> later chapter depends on it, so take your time.

**Time:** about 1 hour 30 minutes — 35 reading, 5 quick check, 20 exercise,
and roughly 30 for running the installation and setup commands as you read
(downloads and enabling APIs take a while).

---

## 2.1 What we are going to install

| Tool | Version | Purpose |
|---|---|---|
| Terraform CLI | 1.17.0 | Reads your configuration and manages infrastructure. |
| Google Cloud CLI (`gcloud`) | 591.0.0 | Creates the project, logs you in, and provides credentials to Terraform. |
| Git | any recent | Downloads the book's code (section 2.8) and provides version control. |
| Visual Studio Code + HashiCorp Terraform extension | latest | Syntax highlighting, autocompletion, formatting. |

**Windows users:** use **WSL2** (Windows Subsystem for Linux) with Ubuntu and
follow the Linux instructions inside WSL. Open PowerShell as administrator and
run `wsl --install`, restart, then open the "Ubuntu" app. Everything in this
book was tested in WSL2.

## 2.2 Installing Terraform 1.17.0

Terraform is a single executable file. Installing it means putting that file
somewhere on your `PATH`. We install an **exact version** so your results
match the book.

### Option A — Manual download (all platforms, recommended)

A fresh Ubuntu (or WSL2) install doesn't include `unzip`; install it first
with `sudo apt-get install -y unzip`.

```console
$ TF_VERSION=1.17.0
$ OS=linux        # or: darwin (macOS)
$ ARCH=amd64      # or: arm64 (Apple Silicon, ARM Linux)
$ curl -LO "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_${OS}_${ARCH}.zip"
$ curl -LO "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_SHA256SUMS"
$ sha256sum --ignore-missing -c "terraform_${TF_VERSION}_SHA256SUMS"     # macOS: shasum -a 256 -c ...
terraform_1.17.0_linux_amd64.zip: OK
$ unzip "terraform_${TF_VERSION}_${OS}_${ARCH}.zip"
$ sudo mv terraform /usr/local/bin/
```

The checksum step proves that the download is complete and not corrupted.
Because the checksum file comes from the same server, it does not prove on
its own that HashiCorp made the file. For that, also download
`terraform_${TF_VERSION}_SHA256SUMS.sig` and check it with HashiCorp's
public GPG key, as described at <https://www.hashicorp.com/security>.

### Option B — Linux package manager (Ubuntu/Debian)

```console
$ sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
$ curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
$ echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
$ sudo apt-get update
$ sudo apt-get install -y terraform=1.17.0-1
$ sudo apt-mark hold terraform     # stop apt from upgrading it automatically
```

### Option C — A version manager (tfenv)

If you work on several projects that need different Terraform versions, a
version manager such as [tfenv](https://github.com/tfutils/tfenv) is handy:

```console
$ tfenv install 1.17.0
$ tfenv use 1.17.0
```

tfenv also reads a file called `.terraform-version` in your project folder, so
everyone on the team automatically uses the same version.

> **macOS with Homebrew:** `brew install hashicorp/tap/terraform` installs the
> *latest* version, not a pinned one. That is fine if it reports 1.17.x;
> otherwise use Option A or C.

### Verify

```console
$ terraform version
Terraform v1.17.0
on linux_amd64
```

Turn on tab completion for Terraform commands (bash or zsh), then restart your
shell:

```console
$ terraform -install-autocomplete
```

## 2.3 Installing the Google Cloud CLI

The Google Cloud CLI provides the `gcloud` command. Follow the instructions
for your platform at <https://cloud.google.com/sdk/docs/install>. On
Ubuntu/WSL2 the pinned install looks like this. Run it from your home folder,
because the archive unpacks a `google-cloud-sdk/` folder where you run it,
and that folder is the installation:

```console
$ cd ~
$ curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-591.0.0-linux-x86_64.tar.gz
$ tar -xf google-cloud-cli-591.0.0-linux-x86_64.tar.gz
$ ./google-cloud-sdk/install.sh
```

On other machines, replace `linux-x86_64` in both file names with
`linux-arm` (ARM Linux), `darwin-arm` (Apple Silicon), or `darwin-x86_64`
(Intel Mac).

Open a new terminal, then:

```console
$ gcloud version
Google Cloud SDK 591.0.0
...
$ gcloud init
```

`gcloud init` runs `gcloud auth login` for you: it opens a browser so you can
log in with your Google account. It then asks you to pick or create a
project. You can skip project selection for now; we create one in the next
step.

## 2.4 Creating a Google Cloud project

Everything in Google Cloud lives inside a **project**. A project groups
resources, permissions, and billing. Deleting a project deletes everything in
it, which makes projects a fantastic safety net for learning.

Project IDs are **globally unique** across all of Google Cloud, and an ID can
never be used again, not even after its project is deleted. The command below
therefore adds your username and a random number:

```console
$ export PROJECT_ID="tf-book-$(whoami | tr -dc 'a-z0-9' | cut -c1-8)-$RANDOM"
$ echo $PROJECT_ID
tf-book-fatih-12345
$ gcloud projects create "$PROJECT_ID" --name="Terraform Book"
$ gcloud config set project "$PROJECT_ID"
```

Save the project ID somewhere — you will use it in every chapter. A good idea
is to add it to your `~/.bashrc` (or `~/.zshrc`) with the actual value, not
the command above. That command contains `$RANDOM`, so it would create a new,
non-existent ID in every new terminal:

```console
$ echo "export PROJECT_ID=$PROJECT_ID" >> ~/.bashrc
$ tail -n1 ~/.bashrc
export PROJECT_ID=tf-book-fatih-12345
```

> [!NOTE]
> **Google Cloud: projects and the resource hierarchy.** A project has three
> identifiers:
>
> * The **project ID** (`tf-book-fatih-12345`): chosen by you, globally
>   unique, and permanent. Terraform and `gcloud` use it almost everywhere.
> * The **project name** ("Terraform Book"): a display label. You can change
>   it at any time, and it doesn't have to be unique.
> * The **project number** (for example `123456789012`): assigned by Google.
>   A few APIs, such as budgets, use it instead of the ID.
>
> Every resource, such as a bucket or a VM, belongs to exactly one project.
> Companies arrange their projects in a tree: an **organization** (tied to the
> company's domain) at the top, **folders** (for example one per department
> or environment) in the middle, and projects at the bottom. Permissions and
> policies set on the organization or a folder are inherited by every project
> below it. A personal Gmail account has no organization, so your project
> stands on its own. That's fine for this book.

### Link a billing account

Most resources require billing to be enabled, even if they fall within the
free tier. New Google Cloud customers receive free trial credits.

```console
$ gcloud billing accounts list
ACCOUNT_ID            NAME                OPEN  MASTER_ACCOUNT_ID
0X0X0X-0X0X0X-0X0X0X  My Billing Account  True
$ export BILLING_ACCOUNT=0X0X0X-0X0X0X-0X0X0X
$ gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT"
```

> [!NOTE]
> **Google Cloud: billing accounts.** A **billing account** holds a payment
> method and pays for the projects linked to it. Billing accounts and projects
> are separate things: one billing account can pay for many projects, and each
> project is linked to at most one billing account. Budgets belong to the
> billing account, not to a project, which is why the budget command below
> names the billing account and then filters on your project. Unlinking
> billing stops a project's paid services, but the real cleanup is deleting
> the project (Appendix C).

### Set a budget alert

A budget alert emails you when spending approaches a limit. It does **not**
stop spending, but it warns you early.

First find your billing account's currency, because the budget amount must
use it:

```console
$ gcloud billing accounts describe "$BILLING_ACCOUNT" --format='value(currencyCode)'
USD
```

Then create the budget:

```console
$ gcloud services enable billingbudgets.googleapis.com
$ export PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
$ gcloud billing budgets create \
    --billing-account="$BILLING_ACCOUNT" \
    --billing-project="$PROJECT_ID" \
    --display-name="terraform-book-budget" \
    --budget-amount=10USD \
    --filter-projects="projects/$PROJECT_NUMBER" \
    --threshold-rule=percent=0.5 \
    --threshold-rule=percent=0.9 \
    --threshold-rule=percent=1.0
```

* `--budget-amount` must use the currency from the first command, for
  example `10EUR`. A different currency is rejected.
* `--billing-project` tells the Budget API which project to bill the API call
  itself to (the "quota project"). By default `gcloud` already uses your
  current project, which you set above, so the flag only makes this explicit.
  It matters when your current project is a different one, or one without
  the Billing Budget API enabled.
* `--filter-projects` uses the project **number**, because that is how
  budgets store projects.

> **Cost note:** The exercises in this book are designed to stay well within
> the free tier or cost a few cents. A budget of 10 (in your billing
> account's currency) gives you a comfortable warning margin. Appendix D
> estimates the cost of every chapter.

### Alternative: the same steps with Terraform

> **Note:** Skip this on your first read. It uses the workflow from
> Chapter 3 and needs the credentials you set up in section 2.6. Use the
> `gcloud` commands above now, and come back here once Terraform is familiar.

Everything above can also be done with Terraform, which is how teams create
projects in practice: the project, its billing link, and its budget are then
reviewed and versioned like any other code. Each `gcloud` command has a
matching resource:

| `gcloud` command | Terraform resource |
|---|---|
| `gcloud projects create` | `google_project` |
| `gcloud billing projects link` | `billing_account` argument of `google_project` |
| `gcloud services enable billingbudgets.googleapis.com` | `google_project_service` |
| `gcloud billing budgets create` | `google_billing_budget` |
| `gcloud config set project` | *(none — this is a local `gcloud` setting)* |

The complete configuration is in `code/ch02-setup/solution/project-bootstrap/`.
The core of it:

```hcl
resource "google_project" "book" {
  project_id      = var.project_id
  name            = "Terraform Book"
  billing_account = var.billing_account

  # The provider protects projects from `terraform destroy` by default.
  # "DELETE" lets you remove the learning project with Terraform.
  deletion_policy = "DELETE"
}

resource "google_billing_budget" "book" {
  provider = google.quota

  billing_account = var.billing_account
  display_name    = "terraform-book-budget"

  budget_filter {
    # Budgets store projects by number. The API converts an ID to a number,
    # so using the ID here would show a change on every plan.
    projects = ["projects/${google_project.book.number}"]
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.budget_amount)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  # ... 0.9 and 1.0 as above

  depends_on = [google_project_service.billingbudgets]
}
```

To use it, copy `terraform.tfvars.example` to `terraform.tfvars`, fill in your
project ID and billing account, and run `terraform init` and
`terraform apply`. If you already created your project with `gcloud`, use a
**new** project ID here; Terraform can't create a project that already
exists. (Alternatively, bring the existing project under Terraform's control
with an `import` block, section 11.5.)

If the budget fails with an error saying the Billing Budget API is not
enabled, wait a minute and run `terraform apply` again: a newly enabled API
can take a moment to become active.

Three things are different from the `gcloud` version:

* **The quota project.** When Terraform uses your personal credentials, the
  Budget and Service Usage APIs need a project to bill API calls to. The
  configuration therefore has a second, aliased provider (`google.quota`,
  Chapter 4) that uses the new project for this.
* **The currency** in `budget_currency` must match your billing account's
  currency, or the API rejects the budget.
* **Keep the state file.** This configuration's state is now the record of
  your project. If you lose it, Terraform no longer knows the project exists.
  `terraform destroy` here deletes the whole project and everything in it.

## 2.5 Enabling APIs

Each Google Cloud service has an API that must be enabled in your project
before it can be used. Enable the ones this book uses:

```console
$ gcloud services enable \
    compute.googleapis.com \
    storage.googleapis.com \
    iam.googleapis.com \
    cloudresourcemanager.googleapis.com \
    secretmanager.googleapis.com \
    run.googleapis.com \
    iamcredentials.googleapis.com \
    sts.googleapis.com
```

This takes a minute or two. (In Chapter 5 you will learn to enable APIs with
Terraform itself using the `google_project_service` resource.)

> [!NOTE]
> **Google Cloud: services and APIs.** Each Google Cloud product (Compute
> Engine for VMs, Cloud Storage, Secret Manager, ...) is a **service** with an
> API named like `compute.googleapis.com`. A new project has only a small set
> of APIs enabled, so nothing is used by accident. Enabling an API is free and
> applies to one project; you pay only for what you then create with it. If
> you forget one, the call fails with `403 ... has not been used in project
> ... or it is disabled` (section 15.6). `gcloud services list --enabled`
> shows what's on.
>
> Google also counts API calls against a project's **quotas**, limits on
> requests and resources. Usually that's the project the resource lives in.
> APIs that act on something other than a project's own resources, such as
> Billing Budgets (a billing account) or Service Usage (which enables APIs),
> can't tell which project to count the call against when you use your
> personal credentials. That's the **quota project** from section 2.4.

> [!NOTE]
> **Google Cloud: the `default` network.** Enabling `compute.googleapis.com` also
> creates a network called `default`, with a subnet in every region and four
> firewall rules. Three of them accept traffic from the whole internet
> (`0.0.0.0/0`): `default-allow-ssh` (port 22), `default-allow-rdp` (port
> 3389), and `default-allow-icmp` (ping). Any VM with a public IP address in
> this network is reachable on those ports. List the rules with:
>
> ```console
> $ gcloud compute firewall-rules list
> ```
>
> Keep the network itself: Chapter 8 places a VM in it and opens only port 80
> with its own rule. The three internet-facing rules aren't needed anywhere in
> this book, so it's safer to delete them:
>
> ```console
> $ gcloud compute firewall-rules delete default-allow-ssh default-allow-rdp default-allow-icmp
> ```
>
> The fourth rule, `default-allow-internal`, only allows traffic between VMs
> inside the network and can stay. In production, teams usually turn off the
> automatic `default` network altogether (with the organization policy
> `compute.skipDefaultNetworkCreation`) and create their own networks, as
> Chapter 5 does.

### Alternative: enabling APIs with Terraform

> **Note:** Like the alternative in section 2.4, skip this on your first read
> and use the `gcloud` command above.

The `project-bootstrap` configuration from section 2.4 also enables these
APIs. One `google_project_service` resource per API would mean eight nearly
identical blocks, so it uses `for_each` (Chapter 7) to create one for each
entry in a set:

```hcl
variable "services" {
  description = "APIs to enable in the project (section 2.5)."
  type        = set(string)
  default = [
    "compute.googleapis.com",
    "storage.googleapis.com",
    # ... the same list as the gcloud command above
  ]
}

resource "google_project_service" "book" {
  provider = google.quota
  for_each = var.services

  project            = google_project.book.project_id
  service            = each.value
  disable_on_destroy = false
}
```

* `disable_on_destroy = false` keeps the APIs enabled when you destroy the
  resource. Disabling an API that other resources still use breaks them, so
  this is the safe choice.
* To enable another API later, add it to the list and run `terraform apply`.
* Like the budget, this resource uses the `google.quota` provider, because
  the Service Usage API needs a quota project when you use your own
  credentials.

## 2.6 Authenticating Terraform to Google Cloud

Terraform needs credentials to call Google Cloud APIs on your behalf. The
recommended way on your own computer is **Application Default Credentials
(ADC)**:

```console
$ gcloud auth application-default login
```

A browser window opens; log in and approve. `gcloud` stores a credentials file
at `~/.config/gcloud/application_default_credentials.json`. The Google
provider for Terraform automatically finds and uses this file — you never put
credentials in your Terraform code.

Some APIs need to know which project to charge for API usage (the "quota
project"). Recent `gcloud` versions set it automatically to your current
`gcloud` project during the login above. Running this command makes sure it
is set:

```console
$ gcloud auth application-default set-quota-project "$PROJECT_ID"
```

### Two logins? Why?

| Command | Who uses the credentials |
|---|---|
| `gcloud auth login` | The `gcloud` command itself. |
| `gcloud auth application-default login` | Libraries and tools such as **Terraform**. |

You need both. `gcloud init` in section 2.3 already ran `gcloud auth login`
for you, so the only extra login is the `application-default` one above.

> [!NOTE]
> **Google Cloud: IAM in one minute.** **Identity and Access Management
> (IAM)** decides who may do what:
>
> * A **principal** is *who*: a Google account (`user:alice@example.com`), a
>   Google group, or a service account (see the next box).
> * A **role** is *what*: a named set of permissions such as
>   `storage.buckets.create`. The **basic roles** (`roles/owner`,
>   `roles/editor`, `roles/viewer`) are very broad; **predefined roles** such
>   as `roles/storage.objectViewer` cover one task in one service and are
>   the better choice in production.
> * An **allow policy** on a resource binds principals to roles. You can set
>   it on an organization, a folder, a project, or a single resource such as a
>   bucket, and grants are inherited downwards: a role on a project applies to
>   everything in it.
>
> You created the project, so you are its Owner, and Terraform, using your ADC
> credentials, can do everything you can. Terraform never has more
> permissions than the identity it runs as. Chapter 13 shows how to manage
> IAM with Terraform.

### What about service account keys?

Older tutorials tell you to download a JSON **service account key** and set
`GOOGLE_APPLICATION_CREDENTIALS`. Avoid this. Keys are long-lived secrets
that are easily leaked. On your laptop, use ADC; in CI/CD pipelines, use
**Workload Identity Federation** (Chapter 21), which needs no keys at all.

> [!NOTE]
> **Google Cloud: service accounts.** A **service account** is an identity
> for software rather than a person: a VM, a Cloud Run service, or a CI/CD
> pipeline. Its email address looks like
> `NAME@PROJECT_ID.iam.gserviceaccount.com`, and you grant it roles like any
> other principal. It has no password. Software gets short-lived tokens for it
> in one of these ways: by running *as* the service account on Google Cloud
> (Chapter 14), by **impersonating** it (section 14.6), through Workload
> Identity Federation (Chapters 16 and 21), or, the option to avoid, with a
> downloaded key file. A service account is also a resource: roles on the
> service account itself, such as `roles/iam.serviceAccountTokenCreator`,
> decide who may act as it.
>
> Your project's IAM page also lists **service agents**: service accounts
> that Google creates to run services on your behalf. Leave them alone.

> **Security tip:** Never commit credentials of any kind to Git. You will add a
> `.gitignore` file in the next chapter.

## 2.7 Setting up your editor

Install [Visual Studio Code](https://code.visualstudio.com/) and the
**HashiCorp Terraform** extension (publisher: HashiCorp). It gives you:

* Syntax highlighting and autocompletion for resources and arguments.
* Hover documentation for the Google provider.
* Format on save (runs `terraform fmt` for you).

Enable format on save by adding these two entries inside the outer `{ }` of
your VS Code `settings.json`. The second one formats `.tfvars` files too:

```json
"[terraform]": {
  "editor.defaultFormatter": "hashicorp.terraform",
  "editor.formatOnSave": true
},
"[terraform-vars]": {
  "editor.defaultFormatter": "hashicorp.terraform",
  "editor.formatOnSave": true
}
```

**Windows users:** install VS Code on Windows, plus Microsoft's **WSL**
extension. Open your work folder from the Ubuntu terminal with `code .`, and
install the HashiCorp Terraform extension when VS Code offers to install it
"in WSL". The extension then runs inside Ubuntu, where Terraform is
installed. Otherwise format on save can't find the `terraform` command.

JetBrains IDEs (IntelliJ, PyCharm, GoLand) have an equivalent "Terraform and
HCL" plugin.

## 2.8 A folder for your work

Download the book's repository with Git. This creates a `terraform-book`
folder in your home directory:

```console
$ cd ~
$ git clone https://github.com/Mufabo/terraform-book.git
$ cd terraform-book
$ ls
book  code  ...
```

If `git` is missing, install it with `sudo apt-get install -y git` (Ubuntu
and WSL2) or `xcode-select --install` (macOS).

Paths such as `code/ch02-setup/exercise` in this book are relative to this
`~/terraform-book` folder. You run Terraform commands *inside* a chapter's
`exercise/` folder. Each folder is an independent Terraform **working
directory**.

## Common mistakes

* **Forgetting `application-default login`.** Terraform then fails with
  `could not find default credentials`. Run the command and try again.
* **Wrong project.** `gcloud config get-value project` shows the current
  project. In Terraform, we always set the project explicitly, so this mostly
  matters for `gcloud` commands.
* **API not enabled.** Errors such as `Compute Engine API has not been used in
  project ... or it is disabled` mean you need `gcloud services enable ...`.
  Newly enabled APIs can take a minute to become active.
* **Billing not linked.** Errors mentioning `billing account ... is not found`
  or `BILLING_DISABLED`.

## Summary

* Install an exact Terraform version (1.17.0) and verify it with
  `terraform version`.
* Create a dedicated Google Cloud project for learning, link billing, and set
  a budget alert.
* Enable the APIs you need.
* Use **Application Default Credentials** for Terraform on your laptop; avoid
  service account keys, and never commit credentials of any kind.

## Quick check

1. Why do we install an exact version of Terraform instead of "the latest"?
2. Which command gives Terraform credentials to call Google Cloud?
3. What happens to the resources in a Google Cloud project when the project
   is deleted?
4. Does a budget alert stop spending when it is reached?
5. Why should you avoid service account key files?

---

## Hands-on exercise: Verify your setup

**Goal:** Confirm that Terraform can authenticate to your Google Cloud project
by running a configuration that *reads* information but creates nothing.

**Estimated time:** 20 minutes (plus installation time)

**Files:** `code/ch02-setup/exercise/`

### Steps

1. Complete sections 2.2 – 2.8 if you have not already.
2. Run the setup check script. It checks the tool versions, your `gcloud`
   project, billing, the APIs from section 2.5, ADC, and its quota project:

   ```console
   $ cd ~/terraform-book/code/ch02-setup/exercise
   $ ./check-setup.sh
   ```

   Fix anything it reports as `MISSING` or `WRONG`. A `WARN` (for example a
   different `gcloud` version) doesn't stop you, but your output may differ
   slightly from the book's.
3. Open `main.tf`. It contains a `data` block that reads details about your
   project (you will learn about data sources in Chapter 5). Replace the
   value marked `TODO (step 3)` with your project ID.
4. Run:

   ```console
   $ terraform init
   $ terraform apply
   ```

   Terraform shows a plan with **no resources to add** but some outputs, and
   asks for confirmation. Type `yes`.
5. Check that the outputs show your project ID and project number.

### Expected result

```
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

project_id     = "tf-book-fatih-12345"
project_number = "123456789012"
```

### Stretch goal

Run `terraform version` inside the folder after `terraform init`. It now also
lists the provider version that was downloaded (`registry.terraform.io/hashicorp/google v8.9.0`).

### Cleanup

No cloud resources were created, so nothing needs to be destroyed. The apply
did write a local `terraform.tfstate` file holding the two outputs (state is
Chapter 9's topic). You can delete it, and the `.terraform` folder, to tidy
up. Keep `.terraform.lock.hcl`.

---

## Quick check answers

1. So that the examples behave exactly as described, and so that everyone on a
   team gets identical results. New versions can change behaviour.
2. `gcloud auth application-default login`.
3. They are all deleted (after a 30-day recovery window during which the
   project can be restored). The project ID stays reserved forever and can't
   be used for a new project.
4. No. It only sends notifications.
5. They are long-lived secrets that can be leaked or stolen and are hard to
   rotate. Prefer ADC locally and Workload Identity Federation in CI/CD.
