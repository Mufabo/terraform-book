# Review — Part II: Writing Configuration

*About 15 minutes. Chapters 5–8, with three questions from Part I.*

Answer each question aloud or in writing **before** you look at the answers.
The questions mix chapters on purpose, and from Part II on they reach back to
earlier Parts: recalling something after a gap is what makes it stick. Mark
every question you couldn't answer and reread the section named in its answer.

## Questions

1. A configuration has a network, a subnet, two firewall rules, and a VM in
   the subnet. In which order are they created, what is created in parallel,
   and how does Terraform know?
2. When do you need `depends_on`? Name two costs of adding it "just in case".
3. A variable has a default and is also set in `TF_VAR_...`, in
   `terraform.tfvars`, in `x.auto.tfvars`, and with `-var`. Put the five
   sources in order, weakest first.
4. A list of names creates one bucket each. Later a name is removed from the
   middle of the list. Compare what happens with `count` and with `for_each`.
   How do you use a list with `for_each`?
5. Write an expression that turns `{ web = "10.0.0.0/24", db = "10.0.1.0/24"
   }` (in `var.subnets`) into a list of strings such as `"web: 10.0.0.0/24"`.
6. Choose the mechanism for each rule: (a) `region` must be one of three
   values; (b) `prod` must not use `e2-micro`; (c) an image found by a data
   source must be `READY`; (d) report, but don't block, when the website is
   down.
7. Which `lifecycle` argument fits each case: a resource must never be
   destroyed by accident; a replacement must not cause downtime; an external
   tool changes one label? What is the limit of the first one?
8. *From Part I:* What does `~> 8.9.0` allow, and what does `~> 8.9` allow?
9. *From Part I:* Which Terraform commands never change real infrastructure?
10. *From Part I:* Explain *declarative* and *imperative* with one sentence
   each. Where does *idempotent* fit?

## From memory

In an empty folder and without the book, write a configuration with a map
variable describing two buckets, one resource block with `for_each`, a
`validation` on one variable, and an output that maps each key to its bucket
URL. `terraform plan` is enough; don't apply.

## Answers

1. Network first; then the subnet and both firewall rules in parallel; the VM
   after the subnet. Terraform builds a dependency graph from the references
   between resources. Section 5.3.
2. Only when a dependency exists without a reference, such as an API or an IAM
   grant that must be in place first. Costs: less parallelism, and a data
   source with `depends_on` is read during apply, which makes its values
   unknown in the plan. Section 5.4.
3. Default, environment variable, `terraform.tfvars`, `*.auto.tfvars`, `-var`
   (and `-var-file`) on the command line. Section 6.3.
4. With `count`, every later element shifts to a new index, so several buckets
   change or are replaced. With `for_each`, only the removed key's bucket is
   destroyed. Convert the list with `toset()`. Sections 7.6–7.7.
5. `[for name, cidr in var.subnets : "${name}: ${cidr}"]`. Section 7.4.
6. (a) `validation`; (b) `precondition` on the VM (or a validation that refers
   to both variables); (c) `postcondition` on the data source; (d) `check`
   block. Sections 8.2–8.4.
7. `prevent_destroy`; `create_before_destroy`; `ignore_changes`.
   `prevent_destroy` disappears together with the resource block if you delete
   the block. Section 8.5.
8. `>= 8.9.0, < 8.10.0`, and `>= 8.9, < 9.0`. Only the last number given may
   increase. Section 4.3.
9. `init`, `fmt`, `validate`, `plan`, `show`, `output`, and the `state`
   commands and `import` (which change only state). Only `apply` and `destroy`
   change infrastructure. Section 3.9.
10. Declarative: you describe the end state and the tool works out the steps.
   Imperative: you write the steps. A declarative tool is idempotent: applying
   the same description again changes nothing. Section 1.3.
