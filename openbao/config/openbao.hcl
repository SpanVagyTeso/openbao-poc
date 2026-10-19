ui = true

# Integrated (Raft) storage, single node
storage "raft" {
  path    = "/openbao/file"
  node_id = "openbao-1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

api_addr     = "http://openbao:8200"
cluster_addr = "http://openbao:8201"

# Auto unseal with a static 32-byte AES-256 key (created by the openbao-keygen service).
# To rotate: move the current key/id to previous_key/previous_key_id and set a new current one.
seal "static" {
  current_key_id = "static-1"
  current_key    = "file:///openbao/secrets/unseal.key"
}
