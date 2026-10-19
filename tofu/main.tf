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

resource "vault_ssh_secret_backend_role" "demo" {
  name                    = "demo"
  backend                 = vault_mount.ssh_client_signer.path
  key_type                = "ca"
  allow_user_certificates = true
  allowed_users           = "demo"
  default_user            = "demo"
  allowed_extensions      = "permit-pty,permit-port-forwarding"
  default_extensions      = { "permit-pty" = "" }
  ttl                     = var.cert_ttl
  max_ttl                 = var.cert_max_ttl

  depends_on = [vault_ssh_secret_backend_ca.ca]
}

# Least-privilege policy for clients that only need to sign keys with the demo role
resource "vault_policy" "ssh_sign_demo" {
  name   = "ssh-sign-demo"
  policy = <<-EOT
    path "${vault_mount.ssh_client_signer.path}/sign/${vault_ssh_secret_backend_role.demo.name}" {
      capabilities = ["create", "update"]
    }
  EOT
}

output "ssh_ca_public_key" {
  value = vault_ssh_secret_backend_ca.ca.public_key
}
