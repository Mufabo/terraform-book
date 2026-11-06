# Preface

## Who this book is for

This book is for people who have **never used Terraform** and may never have
built anything in a cloud before. Maybe you are a developer who keeps being
asked to "just spin up a database", a system administrator moving to the
cloud, a student, or someone preparing for the **HashiCorp Certified:
Terraform Associate (004)** exam. If you can open a terminal and edit a text
file, you have enough background.

## What you will learn

By the end of the book you will be able to:

* Explain what Infrastructure as Code (IaC) is and why teams use it.
* Write Terraform configuration that creates real resources on Google Cloud:
  storage buckets, networks, virtual machines, Cloud Run services, secrets.
* Use variables, outputs, expressions, functions, and modules to keep your
  code reusable and readable.
* Understand Terraform **state**, store it safely in Google Cloud Storage, and
  repair it when reality drifts from your code.
* Use **HCP Terraform** for team collaboration and governance.
* Test your code, enforce company rules with **policy as code**, run Terraform
  automatically in **CI/CD pipelines**, and manage **dev, staging, and
  production** environments.
* Sit the Terraform Associate exam with confidence.

## How each chapter works

Every chapter is designed to take **about one hour**:

| Section | Time | Purpose |
|---|---|---|
| Learning objectives | 1 min | What you will be able to do afterwards. Exam objective IDs such as `[3d]` show which part of the exam it covers. |
| Concepts | ~30 min | Explanations with small examples you can type along. |
| Common mistakes & exam tips | ~3 min | Traps beginners and exam candidates fall into. |
| Summary & quick check | ~5 min | Five questions to test yourself. Answers are at the end of the chapter. |
| Hands-on exercise | ~20 min | Build something real in your own Google Cloud project. |

Code for every exercise is in the `code/` folder. Each chapter has an
`exercise/` folder with `TODO` markers for you to complete and a `solution/`
folder with a working answer. Try the exercise yourself before you peek!

## Conventions

Commands you type in a terminal look like this. Lines starting with `$` are
commands; other lines are output. Do not type the `$`.

```console
$ terraform version
Terraform v1.17.0
on linux_amd64
```

Terraform code looks like this:

```hcl
resource "google_storage_bucket" "example" {
  name     = "my-unique-bucket-name"
  location = "EU"
}
```

Values in `ALL_CAPS` or between angle brackets, such as `PROJECT_ID` or
`<your-project-id>`, are placeholders you replace with your own values.

Boxes like these appear throughout the book:

> **Exam tip:** Information that often appears on the certification exam.

> **Newer than the exam:** A feature added after the Terraform version the
> exam is based on. Useful in practice, not tested.

> **Cost note:** Something that could cost money if you forget to clean up.

## Versions

The book uses **Terraform 1.17.0** and the **Google provider 8.9.0**, the
latest releases when it was written. All versions are pinned so that the
examples keep working. [VERSIONS.md](../VERSIONS.md) lists every tool and
version in one place.

## Why Google Cloud?

Terraform works with hundreds of platforms, and the exam is
**provider-agnostic**: you do not need to know any specific cloud to pass it.
But you learn best by building real things, so we need *one* cloud. Google
Cloud has a generous free tier, a clean project model that makes cleanup easy
(delete the project and everything inside is gone), and excellent Terraform
support. Everything you learn transfers directly to AWS, Azure, or any other
provider.

Let's begin.
