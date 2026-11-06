# Chapter 1 exercise — questions

Answer these by reading `main.tf`.

1. How many resources does this configuration create? List their types.
2. Which provider is used, and which exact version is required?
3. Which Terraform CLI versions are allowed by `required_version`?
4. The subnet refers to `google_compute_network.web.id`. What does that tell
   Terraform about the order in which resources must be created?
5. Which resource must exist before the virtual machine can be created? How
   can you tell from the code?
6. Which network port is opened by the firewall rule, and to whom?
7. How does the firewall rule know which virtual machine it applies to?
8. You want an identical `staging` environment. Which values would you change?
   (In Chapter 6 you will learn to replace these with variables.)
9. Is this configuration declarative or imperative? Why?
10. Estimate how many console clicks it would take to build the same thing by
    hand.
