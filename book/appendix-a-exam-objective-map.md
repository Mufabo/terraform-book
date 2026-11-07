# Appendix A — Terraform Associate (004) Exam Objective Map

Every objective from the official
[exam content list](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-review-004),
and where this book teaches it. Use the last column as a checklist: tick an
objective once you can explain it out loud and have practised it.

## 1. Infrastructure as Code (IaC) with Terraform

| ID | Objective | Chapter / section | ✓ |
|---|---|---|---|
| 1a | Explain what IaC is | 1.2, 1.3 | ☐ |
| 1b | Describe the advantages of IaC patterns | 1.2 | ☐ |
| 1c | Explain how Terraform manages multi-cloud, hybrid cloud, and service-agnostic workflows | 1.4, 1.5 | ☐ |

## 2. Terraform fundamentals

| ID | Objective | Chapter / section | ✓ |
|---|---|---|---|
| 2a | Install and version Terraform providers | 4.3, 4.4 | ☐ |
| 2b | Describe how Terraform uses providers | 4.1, 4.2, 4.5 | ☐ |
| 2c | Write Terraform configuration using multiple providers | 4.6, 4.7 | ☐ |
| 2d | Explain how Terraform uses and manages state | 9.1, 9.2 | ☐ |

## 3. Core Terraform workflow

| ID | Objective | Chapter / section | ✓ |
|---|---|---|---|
| 3a | Describe the Terraform workflow | 1.4, 3.9 | ☐ |
| 3b | Initialize a Terraform working directory | 3.3 | ☐ |
| 3c | Validate a Terraform configuration | 3.5 | ☐ |
| 3d | Generate and review an execution plan for Terraform | 3.6 | ☐ |
| 3e | Apply changes to infrastructure with Terraform | 3.7 | ☐ |
| 3f | Destroy Terraform-managed infrastructure | 3.8 | ☐ |
| 3g | Apply formatting and style adjustments to a configuration | 3.4 | ☐ |

## 4. Terraform configuration

| ID | Objective | Chapter / section | ✓ |
|---|---|---|---|
| 4a | Use and differentiate `resource` and `data` blocks | 5.1, 5.5 | ☐ |
| 4b | Refer to resource attributes and create cross-resource references | 5.2 | ☐ |
| 4c | Use variables and outputs | 6.2 – 6.4 | ☐ |
| 4d | Understand and use complex types | 6.6 | ☐ |
| 4e | Write dynamic configuration using expressions and functions | 7.1 – 7.10 | ☐ |
| 4f | Define resource dependencies in configuration | 5.3, 5.4 | ☐ |
| 4g | Validate configuration using custom conditions | 8.2 – 8.4 | ☐ |
| 4h | Understand best practices for managing sensitive data, including secrets management with Vault | 14.1 – 14.7 | ☐ |

## 5. Terraform modules

| ID | Objective | Chapter / section | ✓ |
|---|---|---|---|
| 5a | Explain how Terraform sources modules | 12.3, 12.5 | ☐ |
| 5b | Describe variable scope within modules | 13.3 | ☐ |
| 5c | Use modules in configuration | 12.1, 12.2, 13.2 | ☐ |
| 5d | Manage module versions | 12.4, 13.6 | ☐ |

## 6. Terraform state management

| ID | Objective | Chapter / section | ✓ |
|---|---|---|---|
| 6a | Describe the local backend | 9.3 | ☐ |
| 6b | Describe state locking | 9.4 | ☐ |
| 6c | Configure remote state using the `backend` block | 10.1 – 10.6 | ☐ |
| 6d | Manage resource drift and Terraform state | 11.1 – 11.4, 11.6, 11.7 | ☐ |

## 7. Maintain infrastructure with Terraform

| ID | Objective | Chapter / section | ✓ |
|---|---|---|---|
| 7a | Import existing infrastructure into your Terraform workspace | 11.5 | ☐ |
| 7b | Use the CLI to inspect state | 9.5, 9.6 | ☐ |
| 7c | Describe when and how to use verbose logging | 15.3 | ☐ |

## 8. HCP Terraform

| ID | Objective | Chapter / section | ✓ |
|---|---|---|---|
| 8a | Use HCP Terraform to create infrastructure | 16.1, 16.3, 16.4, Ch. 16 exercise | ☐ |
| 8b | Describe HCP Terraform collaboration and governance features | 17.1 – 17.7 | ☐ |
| 8c | Describe how to organize and use HCP Terraform workspaces and projects | 16.2, 16.5, 17.8 | ☐ |
| 8d | Configure and use HCP Terraform integration | 16.4, 16.6 | ☐ |

## Beyond the exam

These chapters aren't required for the certification but are essential in
practice:

| Topic | Chapter |
|---|---|
| Setting up a Google Cloud environment | 2 |
| Multiple environments (dev/staging/prod) | 18 |
| Testing (`terraform test`, mocks, TFLint, pre-commit) | 19 |
| Policy as code with `gcloud terraform vet` | 20 |
| CI/CD with GitHub Actions and Workload Identity Federation | 21 |
| Capstone project | 22 |
