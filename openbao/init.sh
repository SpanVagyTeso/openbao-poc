#!/bin/sh
# Initializes OpenBao on first start and saves the root token and recovery key.
# With auto unseal, init also unseals; afterwards this just waits for the server to be ready.
set -eu

INIT_FILE=/openbao/secrets/init.json

rc=0
bao operator init -status >/dev/null || rc=$?
case "${rc}" in
  0) echo "OpenBao already initialized" ;;
  2)
    umask 077
    bao operator init -format=json -recovery-shares=1 -recovery-threshold=1 > "${INIT_FILE}.tmp"
    mv "${INIT_FILE}.tmp" "${INIT_FILE}"
    echo "OpenBao initialized, root token and recovery key saved to ${INIT_FILE}"
    ;;
  *) echo "Cannot reach OpenBao at ${BAO_ADDR}" >&2; exit 1 ;;
esac

# Wait until auto unseal has completed and the node is active
for _ in $(seq 1 30); do
  if bao status >/dev/null 2>&1; then
    echo "OpenBao is unsealed"
    exit 0
  fi
  sleep 1
done
echo "OpenBao did not unseal" >&2
exit 1
