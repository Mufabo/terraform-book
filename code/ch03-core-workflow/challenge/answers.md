# Chapter 3 challenge: answers

* **Finding the arguments.** The bucket's documentation page in the Terraform
  Registry lists `lifecycle_rule` with its nested `condition` and `action`
  blocks, and `storage_class`.
* **`terraform fmt -check`** prints nothing and exits with `0` when the files
  are already formatted.
* **Changing `age` from 30 to 60** is an **in-place update** (`~`): the plan
  shows the old rule removed and the new one added inside the same bucket,
  and ends with `0 to add, 1 to change, 0 to destroy`. Lifecycle rules can be
  changed on an existing bucket.
* **Changing `name`** forces replacement (`-/+`): a bucket can't be renamed.
* **`terraform plan -destroy`** shows `0 to add, 0 to change, 1 to destroy`
  and changes nothing. `terraform destroy` then does it.
