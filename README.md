# Introduction to Terraform on Google Cloud

A hands-on book for **absolute beginners**. You will go from "what is
Infrastructure as Code?" to running Terraform in CI/CD pipelines that manage
separate dev, staging, and production environments on Google Cloud.

* **22 lessons, most about one hour each** (around 24 hours in total; the
  preface lists every chapter's time). Every chapter starts with learning
  objectives and ends with a hands-on exercise.
* **Covers the full HashiCorp Certified: Terraform Associate (004) curriculum.**
  [Appendix A](book/appendix-a-exam-objective-map.md) maps every exam objective
  to the chapter that teaches it.
* **Goes beyond the exam:** testing, policy as code with `gcloud terraform vet`,
  multiple environments, and CI/CD with GitHub Actions.
* **Pinned, current versions:** Terraform 1.17.0 and the Google provider 8.9.0.
  See [VERSIONS.md](VERSIONS.md).

## How to use this book

1. Read the [Preface](book/00-preface.md) and work through
   [Chapter 2](book/02-setting-up.md) to install the tools and create your
   Google Cloud project.
2. Read the chapters in order. Each one builds on the previous ones.
3. At the end of each chapter, open `code/chNN-*/exercise/`, complete the
   `TODO`s, and compare your work with `code/chNN-*/solution/`.
4. For more practice, try the chapter's **challenge**: a task without starter
   files, with a reference solution in `code/chNN-*/challenge/`.
5. **Always run the cleanup step** at the end of an exercise so you do not pay
   for resources you are no longer using.

## Table of contents

See [SUMMARY.md](SUMMARY.md).

## Repository layout

```
book/        Chapters and appendices (Markdown)
code/        One folder per chapter, each with exercise/, solution/, and challenge/
VERSIONS.md  Every pinned tool version in one place
```

## Prerequisites

* A computer running Windows (with WSL2), macOS, or Linux.
* A Google account and a credit card for the Google Cloud free trial
  (new accounts get free credits; the exercises are designed to cost little
  or nothing).
* Comfort using a terminal (`cd`, `ls`, editing a text file). No programming
  or cloud experience is required.

## Cost warning

Cloud resources cost money while they exist. Exercises use free-tier or very
small resources, and every exercise ends with a cleanup step. Chapter 2 shows
you how to set a **budget alert** before you create anything.
[Appendix C](book/appendix-c-cleanup-and-costs.md) explains how to find and
delete anything you forgot, and
[Appendix D](book/appendix-d-cost-estimate.md) estimates what the exercises
cost (well under US$1 in total if you clean up).

## Building the book (optional)

The Markdown renders well on GitHub. Each
[release](https://github.com/Mufabo/terraform-book/releases) also has the
book as an EPUB.

To build the EPUB yourself, install [pandoc](https://pandoc.org/) 3.13 and run:

```bash
epub/build.sh                      # writes terraform-on-google-cloud.epub
```

To publish a new release, push a version tag. The
[Build and release book](.github/workflows/release-book.yml) workflow builds
the EPUB, validates it with EPUBCheck, and attaches it to a GitHub release:

```bash
git tag v1.0.0
git push origin v1.0.0
```
