terraform {
  required_version = ">= 1.10"

  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 19.4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  backend "local" {
    path = "/state/terraform.tfstate"
  }
}

provider "gitlab" {
  base_url = var.gitlab_url
  token    = trimspace(file(var.token_file))
}

# Instance runner that picks up untagged jobs from every project
resource "gitlab_user_runner" "shell" {
  runner_type = "instance_type"
  description = "compose shell runner"
  untagged    = true
}

# The runner service starts once this file exists, already authenticated with the runner token
resource "local_sensitive_file" "runner_config" {
  filename        = var.runner_config_file
  file_permission = "0600"
  content = templatefile("${path.module}/config.toml.tftpl", {
    name  = gitlab_user_runner.shell.description
    url   = var.gitlab_url
    token = gitlab_user_runner.shell.token
  })
}

resource "gitlab_project" "hello_world" {
  name                   = "hello-world"
  description            = "Runs a hello world pipeline on the compose GitLab runner"
  visibility_level       = "private"
  initialize_with_readme = true
  default_branch         = "main"
}

# Committing the file triggers the first pipeline; it waits as pending until the runner is up
resource "gitlab_repository_file" "gitlab_ci" {
  project        = gitlab_project.hello_world.id
  branch         = gitlab_project.hello_world.default_branch
  file_path      = ".gitlab-ci.yml"
  encoding       = "text"
  content        = file("${path.module}/hello-world/.gitlab-ci.yml")
  commit_message = "Add hello world pipeline"
}

output "hello_world_pipelines_path" {
  value = "${gitlab_project.hello_world.path_with_namespace}/-/pipelines"
}
