# Chapter 1 — What Is Infrastructure as Code?

## Learning objectives

By the end of this lesson you will be able to:

* Explain what Infrastructure as Code (IaC) is, in your own words. `[1a]`
* Describe the advantages of IaC compared with clicking in a web console. `[1b]`
* Distinguish **declarative** from **imperative** approaches. `[1a]`
* Explain how Terraform manages multi-cloud, hybrid-cloud, and
  service-agnostic workflows. `[1c]`
* Describe the main building blocks of Terraform: configuration, providers,
  state, and the core workflow. `[1c]`

---

## 1.1 The problem: infrastructure by hand

Imagine your team needs a web application on Google Cloud. Someone logs into
the Google Cloud console and clicks:

1. Create a network.
2. Create a subnet inside it.
3. Create a firewall rule that allows web traffic.
4. Create a virtual machine, choose its size, attach it to the subnet.
5. Create a storage bucket for uploaded images.

It works. A month later, you need an identical **staging** environment for
testing. Nobody remembers exactly which boxes were ticked. Was the firewall
open on port 80 or 8080? Which machine type did we choose? Someone takes
screenshots, someone else writes a wiki page, and the two environments slowly
become different. This is called **configuration drift**, and environments
that cannot be recreated reliably are sometimes called **snowflakes** —
unique, fragile, and impossible to reproduce.

Clicking ("ClickOps") has more problems:

* **No history.** Who changed the firewall last Tuesday, and why?
* **No review.** A typo in production goes live immediately.
* **Slow and error-prone.** Building ten environments means repeating the
  same clicks ten times.
* **Knowledge lives in people's heads.** When they leave, it leaves with them.

## 1.2 The solution: Infrastructure as Code

**Infrastructure as Code (IaC)** means describing your infrastructure —
networks, servers, databases, permissions — in **text files** that a tool reads
to create and manage the real resources for you.

Instead of clicking, you write something like this:

```hcl
resource "google_storage_bucket" "images" {
  name     = "acme-prod-images"
  location = "EU"
}
```

and a tool (Terraform) makes the real bucket exist. Because the description is
just text, you can treat it exactly like application code.

### Advantages of IaC `[1b]`

| Advantage | What it means in practice |
|---|---|
| **Repeatability / consistency** | Run the same code to get identical dev, staging, and prod environments. |
| **Version control** | Store the code in Git. Every change has an author, a date, and a reason (the commit message). You can roll back. |
| **Code review** | Changes go through pull requests; colleagues review them before they reach production. |
| **Automation** | A CI/CD pipeline can apply changes without humans clicking. |
| **Speed** | Create a whole environment in minutes, destroy it when finished. |
| **Documentation** | The code *is* the documentation of what exists. |
| **Reuse** | Package common patterns (for example "a secure bucket") into modules everyone can use. |
| **Fewer errors** | Tools can check the code (formatting, validation, policies) before anything changes. |
| **Cost control** | Easy to tear down temporary environments, so nothing is left running by accident. |

> **Exam tip:** Questions about the benefits of IaC usually revolve around
> *versioning*, *reusability*, *automation*, *consistency*, and *the ability to
> preview changes before applying them*.

## 1.3 Declarative vs. imperative

There are two broad styles of automating infrastructure.

**Imperative** ("how"): you write the *steps* to perform. A shell script is a
good example:

```bash
gcloud compute networks create app-net --subnet-mode=custom
gcloud compute networks subnets create app-subnet --network=app-net --range=10.0.0.0/24 --region=europe-west1
```

Run this script twice and the second run fails, because the network already
exists. To make it safe you must add your own checks ("if the network does not
exist, create it; if its settings differ, update them..."). That gets
complicated quickly.

**Declarative** ("what"): you describe the *desired end state*, and the tool
figures out the steps:

```hcl
resource "google_compute_network" "app" {
  name                    = "app-net"
  auto_create_subnetworks = false
}
```

Terraform compares what you asked for with what already exists and does only
what is needed: create it if missing, update it if different, nothing if it
already matches. Running the same code again is safe. This property —
repeating an operation produces the same result — is called **idempotency**.

Terraform is **declarative**. You describe *what* you want; Terraform works
out *how*.

## 1.4 What is Terraform?

**Terraform** is an open-source-licensed IaC tool created by **HashiCorp**
(now part of IBM). You write configuration in the **HashiCorp Configuration
Language (HCL)**, a simple, human-friendly language. Terraform then talks to
cloud and service APIs to create, change, and delete resources.

> **Note:** Since version 1.6, Terraform is licensed under the Business Source
> License (BSL). You can use it freely for your own infrastructure. A
> community fork called **OpenTofu** exists under an open-source license; it is
> very similar but is not covered by the exam or this book.

### The building blocks

```
 ┌──────────────────────┐      ┌───────────────┐      ┌───────────────────┐
 │  Your configuration  │      │   Terraform   │      │   Provider plugin │      Cloud APIs
 │   (*.tf files, HCL)  │ ───▶ │     Core      │ ───▶ │  (e.g. google)    │ ───▶ (Google Cloud)
 └──────────────────────┘      └──────┬────────┘      └───────────────────┘
                                      │
                                      ▼
                              ┌───────────────┐
                              │     State     │  (what Terraform has created)
                              └───────────────┘
```

* **Configuration** — your `.tf` files describing the desired infrastructure.
* **Terraform Core** — the `terraform` program. It reads the configuration,
  works out what must change, and coordinates the work.
* **Providers** — plugins that know how to talk to a specific API: `google`
  for Google Cloud, `aws` for Amazon Web Services, `github` for GitHub,
  `kubernetes`, `datadog`, and thousands more. Core knows nothing about any
  cloud; providers do the talking.
* **State** — a file in which Terraform records which real resources it
  manages and how they map to your configuration. Chapter 9 covers it in depth.

### The core workflow

Day to day, you use Terraform in a simple loop:

1. **Write** — describe resources in `.tf` files.
2. **Plan** — `terraform plan` shows a preview: what will be created, changed,
   or destroyed.
3. **Apply** — `terraform apply` makes the changes for real.

There are a few supporting commands (`init`, `validate`, `fmt`, `destroy`) that
you will learn in Chapter 3.

The **plan** step is one of Terraform's biggest strengths. You see exactly what
will happen *before* it happens — like a "preview" button for infrastructure.

## 1.5 Multi-cloud, hybrid-cloud, and service-agnostic workflows `[1c]`

Many organisations use more than one platform:

* **Multi-cloud** — for example Google Cloud for data analytics and AWS for an
  older application.
* **Hybrid cloud** — some systems in the company's own data centre (for
  example VMware vSphere) and some in a public cloud.
* **Many SaaS services** — GitHub repositories, Datadog monitors, Cloudflare
  DNS records, PagerDuty schedules, Okta users.

Each platform has its own console, CLI, and native IaC tool (Google Cloud has
Infrastructure Manager and Deployment Manager, AWS has CloudFormation, Azure
has Bicep). Learning all of them is expensive.

Terraform solves this with its **provider** architecture. The *workflow and
language are the same* no matter which platform you target; only the
provider and resource types differ. One configuration can even use several
providers at once:

```hcl
# A Google Cloud bucket...
resource "google_storage_bucket" "site" {
  name     = "acme-website"
  location = "EU"
}

# ...and a DNS record at Cloudflare pointing to it, in the same configuration.
resource "cloudflare_dns_record" "www" {
  zone_id = var.zone_id
  name    = "www"
  type    = "CNAME"
  content = "c.storage.googleapis.com"
  ttl     = 300
}
```

Terraform understands that the DNS record and the bucket belong to the same
system, plans them together, and can even pass values between them. This is
what the exam means by **service-agnostic workflows**: one tool, one
language, one workflow for every service that has an API.

> **Exam tip:** Terraform does **not** let you write one resource that works on
> every cloud. A `google_compute_instance` is not an `aws_instance`. What is
> cloud-agnostic is the *workflow, language, and tooling*, not the resource
> definitions.

## 1.6 Terraform compared with other tools

| Tool | Style | Scope | Notes |
|---|---|---|---|
| **Terraform** | Declarative | Any platform with a provider | Keeps state; huge provider ecosystem. |
| Google Cloud Infrastructure Manager | Declarative | Google Cloud only | A managed service that actually runs Terraform for you. |
| AWS CloudFormation / Azure Bicep | Declarative | One cloud | Native, no separate state file to manage. |
| Pulumi | Declarative, written in general-purpose languages | Many platforms | Uses Python/TypeScript/Go instead of HCL. |
| Ansible, Chef, Puppet | Mostly configuration management | Software *inside* servers | Ansible is procedural; great for installing packages, less ideal for provisioning cloud resources. |

Terraform's sweet spot is **provisioning** — creating and managing the
infrastructure itself. Tools like Ansible are often used *after* Terraform to
configure software on the machines Terraform created. In the cloud, many teams
avoid configuring servers altogether by using container images and managed
services such as Cloud Run.

## 1.7 How Terraform fits into a team

A typical team workflow, which you will build in Part VI, looks like this:

1. An engineer changes a `.tf` file on a Git branch.
2. They open a pull request. A pipeline runs `terraform plan` and posts the
   plan as a comment.
3. A colleague reviews both the code and the plan.
4. After the merge, the pipeline runs `terraform apply`.

Nobody clicks in the console, every change is reviewed, and history is kept
forever in Git.

## Common mistakes and exam tips

* **"Terraform is a configuration-management tool."** Not quite: it is a
  *provisioning* tool. It can run scripts, but that is not its main purpose.
* **"Declarative means no order."** Terraform still works out an order — it
  builds a dependency graph — you just don't write the steps yourself.
* **"Terraform is cloud-agnostic, so one resource works everywhere."** No —
  resources are provider-specific; the workflow is agnostic.
* Remember the word **idempotent**: applying the same configuration twice
  makes no further changes.

## Summary

* IaC describes infrastructure in text files that can be versioned, reviewed,
  reused, and applied automatically.
* Terraform is a declarative IaC tool: you describe the desired state, it
  figures out the steps.
* Terraform Core uses **providers** to talk to APIs and **state** to remember
  what it manages.
* The core workflow is **write → plan → apply**.
* The same language and workflow work across clouds, data centres, and SaaS
  services, which makes multi-cloud and hybrid setups manageable.

## Quick check

1. Name three advantages of IaC over manual configuration.
2. What is the difference between declarative and imperative IaC?
3. What component of Terraform knows how to talk to the Google Cloud API?
4. What does it mean that Terraform is *idempotent*?
5. True or false: with Terraform you can write a single virtual-machine
   resource that runs unchanged on Google Cloud and AWS.

---

## Hands-on exercise: Your first look at Terraform code

**Goal:** Read and reason about a real Terraform configuration before you
install anything. (You will install the tools in the next chapter.)

**Estimated time:** 20 minutes

**Files:** `code/ch01-iac/exercise/`

### Steps

1. Open `code/ch01-iac/exercise/main.tf` in any text editor. It describes a
   small web environment on Google Cloud.
2. Open `code/ch01-iac/exercise/questions.md` and answer the questions in it
   by reading the code. For example: How many resources will be created? Which
   resource must exist before the virtual machine can be created, and how can
   you tell? What would you change to create a second, identical
   environment called `staging`?
3. Write down the clicks you would need to perform in the Google Cloud console
   to create the same infrastructure by hand. Compare the effort with the
   ~40 lines of code.
4. **Reflection:** Write two or three sentences on how you would explain IaC
   to a colleague who has only ever used the console.

### Expected result

You can identify the four resources, the dependencies between them, and the
values you would change for a new environment.

### Check your answers

Compare with `code/ch01-iac/solution/answers.md`.

### Cleanup

Nothing to clean up — you did not create any cloud resources yet.

---

## Quick check answers

1. Any three of: repeatability, version control, code review, automation,
   speed, documentation, reuse, fewer errors, cost control.
2. Declarative describes the desired *end state* and lets the tool figure out
   the steps; imperative describes the *steps* to execute.
3. The **provider** (here, `hashicorp/google`).
4. Applying the same configuration repeatedly results in the same
   infrastructure; once reality matches the code, further applies change
   nothing.
5. False. Resources are provider-specific; the *workflow* is cloud-agnostic.
