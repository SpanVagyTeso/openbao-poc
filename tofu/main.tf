terraform {
  required_version = ">= 1.10"

  required_providers {
    # The Vault provider is API-compatible with OpenBao
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13"
    }
  }

  backend "local" {
    path = "/state/terraform.tfstate"
  }
}

provider "vault" {
  address = var.bao_addr
  token   = jsondecode(file(var.init_file)).root_token

  # Use the token as-is instead of minting a short-lived child token
  skip_child_token = true
}

resource "vault_mount" "ssh_client_signer" {
  path        = var.ssh_mount
  type        = "ssh"
  description = "SSH user certificate authority"
}

# CA key pair is generated inside OpenBao; the private key never leaves it
resource "vault_ssh_secret_backend_ca" "ca" {
  backend              = vault_mount.ssh_client_signer.path
  generate_signing_key = true
  key_type             = "ed25519"
}

# One SSH role per user: certificates can only carry that user's own login name as principal
resource "vault_ssh_secret_backend_role" "user" {
  for_each = var.ssh_users

  name                    = each.key
  backend                 = vault_mount.ssh_client_signer.path
  key_type                = "ca"
  allow_user_certificates = true
  allowed_users           = each.key
  default_user            = each.key
  allowed_extensions      = "permit-pty,permit-port-forwarding"
  default_extensions      = { "permit-pty" = "" }
  ttl                     = var.cert_ttl
  max_ttl                 = var.cert_max_ttl

  depends_on = [vault_ssh_secret_backend_ca.ca]
}

# Least-privilege policy per user: may only sign keys with their own SSH role
resource "vault_policy" "ssh_sign" {
  for_each = var.ssh_users

  name   = "ssh-sign-${each.key}"
  policy = <<-EOT
    path "${vault_mount.ssh_client_signer.path}/sign/${vault_ssh_secret_backend_role.user[each.key].name}" {
      capabilities = ["create", "update"]
    }
  EOT
}

# GitLab CI jobs log in with their id_token; signatures are checked against GitLab's public keys
resource "vault_jwt_auth_backend" "gitlab" {
  path         = "jwt"
  type         = "jwt"
  description  = "GitLab CI id_tokens"
  jwks_url     = var.gitlab_jwks_url
  bound_issuer = var.gitlab_issuer
}

# One JWT role per user, named like the user. It only accepts id_tokens of pipelines started by that
# GitLab user (login and email must both match) and only grants that user's signing policy.
resource "vault_jwt_auth_backend_role" "gitlab_ssh" {
  for_each = var.ssh_users

  backend         = vault_jwt_auth_backend.gitlab.path
  role_name       = each.key
  role_type       = "jwt"
  bound_audiences = [var.gitlab_audience]
  user_claim      = "user_email"
  bound_claims = {
    user_login = each.key
    user_email = each.value
  }
  token_policies = [vault_policy.ssh_sign[each.key].name]
  token_ttl      = 300
}

output "ssh_ca_public_key" {
  value = vault_ssh_secret_backend_ca.ca.public_key
}
