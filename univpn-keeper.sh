#!/bin/bash

# Load configuration from Environment Variables or use defaults
TARGET=${RECONNECT_PING_TARGET:-8.8.8.8}
ENABLE=${AUTO_RECONNECT:-false}
GRACE=${RECONNECT_GRACE_PERIOD:-60}

while true; do
  echo "[Keeper] Starting UniVPN..."
  
  # Start UniVPN in the background
  /usr/local/UniVPN/UniVPN &
  VPN_PID=$!

  if [ "$ENABLE" = "true" ]; then
    echo "[Keeper] Auto-reconnect ENABLED. Target: $TARGET"
    echo "[Keeper] Waiting ${GRACE}s for login/connection..."
    sleep $GRACE

    # Monitor Loop: Check connection as long as the process is alive
    while kill -0 $VPN_PID 2>/dev/null; do
      # Try pinging.
      if ! ping -c 1 -W 2 "$TARGET" > /dev/null 2>&1; then
         # Double check to prevent false positives (wait 1 sec and retry)
         sleep 1
         if ! ping -c 1 -W 2 "$TARGET" > /dev/null 2>&1; then
             echo "[Keeper] Connection lost (Ping failed). Killing VPN..."
             kill $VPN_PID
             break
         fi
      fi
      # Check every 10 seconds
      sleep 10
    done
  else
    echo "[Keeper] Auto-reconnect DISABLED. Waiting for process exit..."
    # Wait for the process to end naturally
    wait $VPN_PID
  fi

  echo "[Keeper] UniVPN exited. Restarting in 5 seconds..."
  sleep 5
done
