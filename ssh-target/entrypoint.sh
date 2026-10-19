#!/bin/bash
set -euo pipefail

CA_FILE=/etc/ssh/trusted-user-ca-keys.pem

# Fetch the CA public key (unauthenticated endpoint) from OpenBao
echo "Fetching SSH CA public key from ${BAO_ADDR}/v1/${SSH_CA_MOUNT}/public_key"
curl -sSf --retry 30 --retry-all-errors --retry-delay 2 \
  "${BAO_ADDR}/v1/${SSH_CA_MOUNT}/public_key" -o "${CA_FILE}"
chmod 0644 "${CA_FILE}"
echo "Trusting CA: $(cat "${CA_FILE}")"

ssh-keygen -A

rm -f /var/run/rsyslogd.pid
rsyslogd
touch /var/log/secure /var/log/messages

# Mirror syslog files to the container output so `docker compose logs` shows them
tail -F /var/log/secure /var/log/messages &

sshd -t
exec /usr/sbin/sshd -D
