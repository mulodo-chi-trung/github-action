workflow "Apply" {
  resolves = "terraform-apply"
  # Here you can see we're reacting to the pull_request event.
  on = "pull_request"
}

# Filter to pull request merged events.
action "merged-prs-filter" {
  uses = "actions/bin/filter@master"
  args = "merged true"
}

# Additionally, filter to pull requests merged to master.
action "base-branch-filter" {
  uses = "hashicorp/terraform-github-actions/base-branch-filter@v0.4.0"
  # If you want to run apply when merging into other branches,
  # set this regex.
  args = "^master$"
  needs = "merged-prs-filter"
}

# init must be run before apply.
action "terraform-init-apply" {
  uses = "hashicorp/terraform-github-actions/init@v0.4.0"
  needs = "base-branch-filter"
  env = {
    TF_ACTION_WORKING_DIR = "~/github-action/"
  }
}

# Finally, run apply.
action "terraform-apply" {
  needs = "terraform-init-apply"
  uses = "hashicorp/terraform-github-actions/apply@v0.4.0"
  env = {
    TF_ACTION_WORKING_DIR = "~/github-action/"
    TF_ACTION_WORKSPACE = "default"
  }
}
