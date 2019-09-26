terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "mulodo_test_team"

    workspaces {
      name = "github-action-test-1"
    }
  }
}