variable "bao_addr" {
  type    = string
  default = "http://openbao:8200"
}

variable "init_file" {
  description = "Output of `bao operator init -format=json`, holds the root token"
  type        = string
  default     = "/secrets/init.json"
}

variable "ssh_mount" {
  type    = string
  default = "ssh-client-signer"
}

variable "cert_ttl" {
  description = "Default lifetime of signed certificates, in seconds"
  type        = number
  default     = 300
}

variable "cert_max_ttl" {
  description = "Maximum lifetime a client may request, in seconds"
  type        = number
  default     = 1800
}

variable "gitlab_jwks_url" {
  description = "GitLab's id_token signing keys, as reachable from OpenBao"
  type        = string
  default     = "http://gitlab:8929/oauth/discovery/keys"
}

variable "gitlab_issuer" {
  description = "iss claim of GitLab id_tokens (GitLab's external_url)"
  type        = string
  default     = "http://localhost:8929"
}

variable "gitlab_audience" {
  description = "aud the CI job requests in its id_tokens section"
  type        = string
  default     = "openbao"
}

variable "ssh_users" {
  description = <<-EOT
    Users who may get SSH certificates, as Linux/GitLab username => GitLab email.
    Each user can only get a certificate for their own login on ssh-target.
    New users also need an account in ssh-target/Dockerfile and gitlab/seed.rb.
  EOT
  type        = map(string)
  default = {
    "fodor.kristof" = "fodor.kristof@microsec.hu"
    "other-user"    = "other-user@microsec.hu"
  }
}
