# Preface

## Who this book is for

This book is for people who have **never used Terraform** and may never have
built anything in a cloud before. Maybe you are a developer who keeps being
asked to "just spin up a database", a system administrator moving to the
cloud, a student, or someone preparing for the **HashiCorp Certified:
Terraform Associate (004)** exam. If you can open a terminal and edit a text
file, you have enough background to start.

### What you need to know, and when

Parts I to IV (everything the exam covers except HCP Terraform) need very
little. The last Part asks for more, because it builds a real delivery
pipeline:

| Part | You should be able to | If you can't yet |
|---|---|---|
| I–IV (Chapters 1–15) | Move around in a terminal (`cd`, `ls`), set an environment variable, edit text files. Chapter 2 walks you through installing everything. From Chapter 2 on you run `git clone` once; that is all the Git you need. | An hour with any command-line introduction is enough. |
| V (Chapters 16–17) | The same, plus a free HCP Terraform account. Chapter 17's exercise uses a GitHub account and `git push`. | You can read both chapters for the exam without doing the exercises. |
| VI (Chapters 18–22) | Use Git branches and pull requests on GitHub, read YAML, and read a short shell script. Chapter 20 teaches the little Rego it needs. | Work through a Git and GitHub tutorial first. These chapters are not on the exam, so you can also sit the exam and return to them later. |

You also need a Google account and a payment method to open a Google Cloud
billing account. Appendix D shows that the exercises cost next to nothing,
but Google asks for the payment method anyway.

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

Most chapters take **about an hour**. Every chapter has the same parts:

| Section | Time | Purpose |
|---|---|---|
| Learning objectives | 1 min | What you will be able to do afterwards. Exam objective IDs such as `[3d]` show which part of the exam it covers. |
| Concepts, common mistakes, and summary | 15–35 min | Explanations with small examples you can type along, the traps beginners and exam candidates fall into, and a recap. |
| Quick check | ~5 min | Five recall questions and two exam-style scenario questions. Answers are at the end of the chapter. |
| Hands-on exercise | 20–45 min | Build something real in your own Google Cloud project. |
| Stretch goal and challenge | optional | Go further without step-by-step guidance. |

### How long each chapter takes

Each chapter states its own estimate below the learning objectives. Plan for
about **25 hours** for the whole book, including the six Part reviews:

| Chapter | Reading | Exercise | Total |
|---|---|---|---|
| 1. What Is Infrastructure as Code? | 20 min | 20 min | 45 minutes |
| 2. Setting Up Your Environment | 30 min + 30 min setup | 20 min | 1 hour 25 minutes |
| 3. Your First Configuration and the Core Workflow | 35 min | 25 min | 1 hour 5 minutes |
| 4. Providers | 25 min | 25 min | 55 minutes |
| 5. Resources, Data Sources, and Dependencies | 25 min | 25 min | 55 minutes |
| 6. Variables, Outputs, and Locals | 15 min | 25 min | 45 minutes |
| 7. Expressions and Functions | 20 min | 25 min | 50 minutes |
| 8. Custom Conditions and Lifecycle Rules | 20 min | 25 min | 50 minutes |
| 9. Understanding State | 15 min | 25 min | 45 minutes |
| 10. Remote State on Google Cloud Storage | 20 min | 35 min | 1 hour |
| 11. Drift, Import, and Refactoring | 20 min | 30 min | 55 minutes |
| 12. Using Modules | 15 min | 25 min | 45 minutes |
| 13. Writing Your Own Modules | 15 min | 30 min | 50 minutes |
| 14. Sensitive Data and Secrets | 20 min | 25 min | 50 minutes |
| 15. Troubleshooting and Logging | 20 min | 25 min | 50 minutes |
| 16. HCP Terraform Basics | 20 min | 35 min | 1 hour |
| 17. Collaboration and Governance in HCP Terraform | 20 min | 35 min | 1 hour |
| 18. Managing Multiple Environments | 15 min | 30 min | 50 minutes |
| 19. Testing Terraform Code | 20 min | 30 min | 55 minutes |
| 20. Policy as Code with `gcloud terraform vet` | 25 min | 30 min | 1 hour |
| 21. CI/CD with GitHub Actions | 25 min | 45 min | 1 hour 15 minutes |
| 22. Capstone Project and Exam Preparation | 15 min | 2–3 h + two 40-min tests | 3½–4½ hours |

Each of the book's six Parts ends with a **review** of about 15 minutes:
ten questions that mix the Part's chapters and reach back to earlier Parts,
plus a small task to do from memory. Don't skip them. Answering a question
again after a gap of days is what moves it into long-term memory, and it
shows you what to reread before the gap gets longer.

The totals include five minutes for the quick check. Reading is counted at
about 100 words a minute, a careful pace that leaves room for code and
command output. The exercise times assume that nothing goes badly wrong. If
this is your first time in a terminal or in a cloud, expect to need longer,
above all in Chapters 2 and 3; an error you have to track down yourself is
part of the learning, not time lost.

Code for every exercise is in the `code/` folder. Each chapter has an
`exercise/` folder with `TODO` markers for you to complete and a `solution/`
folder with a working answer. Try the exercise yourself before you peek!

Each exercise ends with two optional extras. The **stretch goal** takes the
exercise one step further. The **challenge** is a new, small task described
only by its requirements: no starter files, no `TODO`s, and often an
argument or a command you have to look up yourself. Filling in `TODO`s shows
that you followed the chapter; the challenge shows whether you can use it on
your own, which is what your job and the exam will ask of you. Reference
solutions are in each chapter's `challenge/` folder. The challenges take 15
to 40 minutes each and aren't counted in the times above. If you're short of
time, do the challenge rather than the stretch goal.

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

This book teaches Terraform, not Google Cloud, but you can't build on a
cloud you don't understand. Wherever a Google Cloud concept first appears,
a box like this one explains it:

> [!NOTE]
> **Google Cloud: projects.** A short explanation of a Google Cloud concept,
> such as what a project, a region, or a service account is. Skip the boxes
> for concepts you already know; they aren't part of the exam.

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
