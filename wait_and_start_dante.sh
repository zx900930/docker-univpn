#!/bin/bash

INTERFACE="cnem_vnic"
DANTE_COMMAND="/usr/sbin/danted -f /etc/danted.conf"
CHECK_INTERVAL=5 # Seconds between checks
MAX_CHECKS=60    # Wait a maximum of 5 minutes (60 checks * 5 seconds)

echo "[Wrapper] Waiting for interface ${INTERFACE} to appear..."

COUNT=0
# Loop until the interface exists or we time out
while ! ip link show "${INTERFACE}" > /dev/null 2>&1; do
  if [ ${COUNT} -ge ${MAX_CHECKS} ]; then
    echo "[Wrapper] ERROR: Interface ${INTERFACE} did not appear after $((MAX_CHECKS * CHECK_INTERVAL)) seconds. Exiting." >&2
    exit 1
  fi
  echo "[Wrapper] Interface ${INTERFACE} not found yet, waiting ${CHECK_INTERVAL}s... (${COUNT}/${MAX_CHECKS})"
  sleep ${CHECK_INTERVAL}
  COUNT=$((COUNT + 1))
done

echo "[Wrapper] Interface ${INTERFACE} found. Starting Dante server..."
# Use exec to replace this script process with the danted process
exec ${DANTE_COMMAND}
