#!/bin/sh
# Creates the static auto-unseal key once. Never overwrites an existing key:
# losing or replacing it makes the stored data unrecoverable.
set -eu

KEY=/openbao/secrets/unseal.key

if [ -s "${KEY}" ]; then
  echo "Unseal key already exists at ${KEY}"
  exit 0
fi

umask 077
head -c 32 /dev/urandom > "${KEY}"
chown openbao:openbao "${KEY}"
echo "Created new unseal key at ${KEY}"
