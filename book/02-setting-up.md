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

---

## 2.1 What we are going to install

| Tool | Version | Purpose |
|---|---|---|
| Terraform CLI | 1.17.0 | Reads your configuration and manages infrastructure. |
| Google Cloud CLI (`gcloud`) | 591.0.0 | Creates the project, logs you in, and provides credentials to Terraform. |
| Git | any recent | Version control (needed from Chapter 12 onwards). |
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

The checksum step proves that the file you downloaded is exactly the file
HashiCorp published.

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
Ubuntu/WSL2 the pinned install looks like this:

```console
$ curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-591.0.0-linux-x86_64.tar.gz
$ tar -xf google-cloud-cli-591.0.0-linux-x86_64.tar.gz
$ ./google-cloud-sdk/install.sh
```

Open a new terminal, then:

```console
$ gcloud version
Google Cloud SDK 591.0.0
...
$ gcloud init
```

`gcloud init` opens a browser so you can log in with your Google account, then
asks you to pick or create a project. You can skip project selection for now;
we create one in the next step.

## 2.4 Creating a Google Cloud project

Everything in Google Cloud lives inside a **project**. A project groups
resources, permissions, and billing. Deleting a project deletes everything in
it, which makes projects a fantastic safety net for learning.

Project IDs are **globally unique** across all of Google Cloud, so add
something personal, such as your initials and a random number:

```console
$ export PROJECT_ID="tf-book-$(whoami | tr -dc 'a-z0-9' | cut -c1-8)-$RANDOM"
$ echo $PROJECT_ID
tf-book-fatih-12345
$ gcloud projects create "$PROJECT_ID" --name="Terraform Book"
$ gcloud config set project "$PROJECT_ID"
```

Save the project ID somewhere — you will use it in every chapter. A good idea
is to add the `export PROJECT_ID=...` line to your `~/.bashrc` or `~/.zshrc`.

### Link a billing account

Most resources require billing to be enabled, even if they fall within the
free tier. New Google Cloud customers receive free trial credits.

```console
$ gcloud billing accounts list
ACCOUNT_ID            NAME                OPEN
0X0X0X-0X0X0X-0X0X0X  My Billing Account  True
$ export BILLING_ACCOUNT=0X0X0X-0X0X0X-0X0X0X
$ gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT"
```

### Set a budget alert

A budget alert emails you when spending approaches a limit. It does **not**
stop spending, but it warns you early.

```console
$ gcloud services enable billingbudgets.googleapis.com
$ gcloud billing budgets create \
    --billing-account="$BILLING_ACCOUNT" \
    --display-name="terraform-book-budget" \
    --budget-amount=10USD \
    --filter-projects="projects/$PROJECT_ID" \
    --threshold-rule=percent=0.5 \
    --threshold-rule=percent=0.9 \
    --threshold-rule=percent=1.0
```

> **Cost note:** The exercises in this book are designed to stay well within
> the free tier or cost a few cents. A budget of 10 USD (or your local
> currency) gives you a comfortable warning margin.

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
    # Budgets filter by project number, not project ID.
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
`terraform apply`. Three things are different from the `gcloud` version:

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
    artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    iamcredentials.googleapis.com \
    sts.googleapis.com
```

This takes a minute or two. (In Chapter 5 you will learn to enable APIs with
Terraform itself using the `google_project_service` resource.)

### Alternative: enabling APIs with Terraform

> **Note:** Like the alternative in section 2.4, skip this on your first read
> and use the `gcloud` command above.

The `project-bootstrap` configuration from section 2.4 also enables these
APIs. One `google_project_service` resource per API would mean ten nearly
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
project"):

```console
$ gcloud auth application-default set-quota-project "$PROJECT_ID"
```

### Two logins? Why?

| Command | Who uses the credentials |
|---|---|
| `gcloud auth login` | The `gcloud` command itself. |
| `gcloud auth application-default login` | Libraries and tools such as **Terraform**. |

You need both.

### What about service account keys?

Older tutorials tell you to download a JSON **service account key** and set
`GOOGLE_APPLICATION_CREDENTIALS`. Avoid this. Keys are long-lived secrets
that are easily leaked. On your laptop, use ADC; in CI/CD pipelines, use
**Workload Identity Federation** (Chapter 21), which needs no keys at all.

> **Security tip:** Never commit credentials of any kind to Git. You will add a
> `.gitignore` file in the next chapter.

## 2.7 Setting up your editor

Install [Visual Studio Code](https://code.visualstudio.com/) and the
**HashiCorp Terraform** extension (publisher: HashiCorp). It gives you:

* Syntax highlighting and autocompletion for resources and arguments.
* Hover documentation for the Google provider.
* Format on save (runs `terraform fmt` for you).

Enable format on save by adding this to your VS Code `settings.json`:

```json
"[terraform]": {
  "editor.defaultFormatter": "hashicorp.terraform",
  "editor.formatOnSave": true
}
```

JetBrains IDEs (IntelliJ, PyCharm, GoLand) have an equivalent "Terraform and
HCL" plugin.

## 2.8 A folder for your work

Create a folder for the book's exercises and clone or copy the book's `code`
folder into it:

```console
$ mkdir -p ~/terraform-book && cd ~/terraform-book
```

Throughout the book, you run Terraform commands *inside* a chapter's
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
* Use **Application Default Credentials** for Terraform on your laptop; never
  use or commit service account keys.

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

1. Complete sections 2.2 – 2.7 if you have not already.
2. Run the setup check script, which verifies every tool and setting:

   ```console
   $ cd code/ch02-setup/exercise
   $ ./check-setup.sh
   ```

   Fix anything it reports as `MISSING` or `WRONG`.
3. Open `main.tf`. It contains a `data` block that reads details about your
   project (you will learn about data sources in Chapter 5). Replace the
   `TODO` with your project ID.
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

Nothing was created, so nothing needs to be destroyed. You can delete the
`.terraform` folder if you want to save disk space.

---

## Quick check answers

1. So that the examples behave exactly as described, and so that everyone on a
   team gets identical results. New versions can change behaviour.
2. `gcloud auth application-default login`.
3. They are all deleted (after a 30-day recovery window during which the
   project can be restored).
4. No. It only sends notifications.
5. They are long-lived secrets that can be leaked or stolen and are hard to
   rotate. Prefer ADC locally and Workload Identity Federation in CI/CD.
