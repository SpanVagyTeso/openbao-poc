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

# Acts as fodor.kristof (root token with sudo scope), so commits and their pipelines belong to that user
provider "gitlab" {
  alias    = "fodor"
  base_url = var.gitlab_url
  token    = trimspace(file(var.token_file))
  headers  = { Sudo = data.gitlab_user.fodor.username }
}

# Demo users are created by seed.rb, because the API rejects their password as too weak
data "gitlab_user" "fodor" {
  username = "fodor.kristof"
}

data "gitlab_user" "other" {
  username = "other-user"
}

data "gitlab_user" "unknown" {
  username = "unknown"
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
  description            = "Gets an SSH certificate from OpenBao with the job's id_token and logs in to ssh-target"
  visibility_level       = "private"
  initialize_with_readme = true
  default_branch         = "main"
}

# All users get the same GitLab permissions; only OpenBao decides who may get which SSH certificate
resource "gitlab_project_membership" "demo" {
  for_each = {
    fodor   = data.gitlab_user.fodor.id
    other   = data.gitlab_user.other.id
    unknown = data.gitlab_user.unknown.id
  }

  project      = gitlab_project.hello_world.id
  user_id      = each.value
  access_level = "maintainer"
}

# Committed by fodor.kristof, so the first pipeline runs as that user and OpenBao signs the key.
# It waits as pending until the runner is up.
resource "gitlab_repository_file" "gitlab_ci" {
  provider = gitlab.fodor

  project        = gitlab_project.hello_world.id
  branch         = gitlab_project.hello_world.default_branch
  file_path      = ".gitlab-ci.yml"
  encoding       = "text"
  content        = file("${path.module}/hello-world/.gitlab-ci.yml")
  commit_message = "Add SSH certificate pipeline"

  # Stacks created before the demo users existed already have this file, but fodor.kristof can't see it
  # during refresh (not a member yet), so tofu plans a create; update the existing file instead of failing
  overwrite_on_create = true

  depends_on = [gitlab_project_membership.demo]
}

output "hello_world_pipelines_path" {
  value = "${gitlab_project.hello_world.path_with_namespace}/-/pipelines"
}
