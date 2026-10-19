#!/bin/bash
# Generates a throwaway key, gets it signed by OpenBao, and runs a command on the target.
set -euo pipefail

BAO_TOKEN=${BAO_TOKEN:-$(jq -r .root_token "${BAO_INIT_FILE}")}

KEY=~/.ssh/id_ed25519
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -q -t ed25519 -N '' -f "${KEY}" <<<y >/dev/null

# Ask OpenBao to sign the public key
jq -n --arg k "$(cat "${KEY}.pub")" --arg u "${SSH_USER}" \
  '{public_key: $k, valid_principals: $u}' |
curl -sSf -H "X-Vault-Token: ${BAO_TOKEN}" -X POST --data @- \
  "${BAO_ADDR}/v1/${SSH_CA_MOUNT}/sign/${SSH_ROLE}" |
jq -j .data.signed_key > "${KEY}-cert.pub"

echo "--- certificate ---"
ssh-keygen -L -f "${KEY}-cert.pub"

# Trust the target's host key on first use; the user cert is what's being demonstrated
echo "--- ssh ${SSH_USER}@${SSH_HOST} ---"
exec ssh -i "${KEY}" -o StrictHostKeyChecking=accept-new "${SSH_USER}@${SSH_HOST}" "$@"
