variable "gitlab_url" {
  description = "GitLab URL as seen from inside the compose network"
  type        = string
  default     = "http://gitlab:8929"
}

variable "token_file" {
  description = "Root personal access token, seeded by seed-token.rb"
  type        = string
  default     = "/secrets/root-token"
}

variable "runner_config_file" {
  description = "Where to write the gitlab-runner config.toml (shared volume with the runner)"
  type        = string
  default     = "/runner-config/config.toml"
}
