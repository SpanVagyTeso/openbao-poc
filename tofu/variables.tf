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
