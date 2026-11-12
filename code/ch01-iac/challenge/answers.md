# Chapter 1 challenge: answers

1. **The declarative version** is in `main.tf`: one resource block per
   `gcloud ... create` command. Don't worry if your argument names differ;
   you'll learn to look them up in Chapter 4. What matters is the shape: each
   block says *what should exist*, not *which command to run*. Note how the
   firewall rule refers to the network (`google_compute_network.share.id`)
   instead of repeating its name. That reference is how Terraform knows the
   network must be created first.

2. **Running it twice.** The script fails at its first line: the bucket
   already exists, and `gcloud storage buckets create` returns an error. With
   `set -e` the script stops there. Without it, all three commands fail one
   after the other. Terraform compares the configuration with what exists,
   finds no difference, and does nothing ("No changes"). That's idempotency.

3. **The port was changed by hand to 8443.** The script can't notice: it only
   knows how to *create* the rule, and creating fails because the rule
   exists. The wrong port stays. Terraform reads the real rule, sees that it
   differs from the configuration, and plans an in-place update back to 443.
   This is the drift detection you'll meet in Chapter 11.

4. **A second environment.** With the script you copy it and edit every name
   by hand, or add shell variables and your own checks. With Terraform you
   change the values that differ (project, names), ideally through the
   variables of Chapter 6, and apply the same code again.
