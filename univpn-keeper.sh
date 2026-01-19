#!/bin/bash

# Load configuration
TARGET=${RECONNECT_PING_TARGET:-8.8.8.8}
ENABLE=${AUTO_RECONNECT:-false}
GRACE=${RECONNECT_GRACE_PERIOD:-60}
APP_CMD="/usr/local/UniVPN/UniVPN"

# Helper function for logging with timestamp
log() {
    echo "[Keeper] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Helper function to ensure a process is dead
ensure_stopped() {
    local pid=$1
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        log "Stopping VPN process (PID: $pid)..."
        kill "$pid"
        
        # Wait up to 20 seconds for graceful exit
        local count=0
        while kill -0 "$pid" 2>/dev/null; do
            if [ $count -ge 20 ]; then
                log "Process stuck. Force killing (SIGKILL)..."
                kill -9 "$pid" 2>/dev/null
                break
            fi
            sleep 1
            ((count++))
        done
        log "Old process stopped."
    fi
}

# Cleanup any stray instances on container start
pkill -f "$APP_CMD" 2>/dev/null

while true; do
  log "Starting UniVPN..."
  
  # Start UniVPN in the background
  $APP_CMD &
  VPN_PID=$!
  log "UniVPN started with PID: $VPN_PID"

  if [ "$ENABLE" = "true" ]; then
    log "Auto-reconnect ENABLED. Target: $TARGET"
    log "Waiting ${GRACE}s for login/connection..."
    sleep $GRACE

    # Monitor Loop
    while kill -0 $VPN_PID 2>/dev/null; do
      # 1. First Ping Test
      if ! ping -c 1 -W 2 "$TARGET" > /dev/null 2>&1; then
         # 2. Log the first failure
         log "WARNING: Ping check to $TARGET failed. Retrying in 2 seconds..."
         sleep 2
         
         # 3. Second Ping Test (Double Check)
         if ! ping -c 1 -W 2 "$TARGET" > /dev/null 2>&1; then
             log "ERROR: Connection lost (Ping failed). Triggering restart..."
             break # Break the inner loop to reach cleanup logic
         fi
      fi
      
      # Wait before next check
      sleep 10
    done
  else
    log "Auto-reconnect DISABLED. Waiting for process exit..."
    wait $VPN_PID
  fi

  # Ensure the old process is completely dead before restarting loop
  ensure_stopped $VPN_PID

  log "Restarting in 5 seconds..."
  sleep 5
done
