#!/bin/bash
# UniVPN Keeper Script - Compatible with supervisor and CLI setup

# Configuration from environment variables
TARGET=${RECONNECT_PING_TARGET:-8.8.8.8}
ENABLE=${AUTO_RECONNECT:-false}
GRACE=${RECONNECT_GRACE_PERIOD:-60}
CHECK_INTERVAL=${HEALTH_CHECK_INTERVAL:-10}
RETRY_DELAY=${RETRY_DELAY:-5}
VPN_USERNAME=${VPN_USERNAME:-}
VPN_PASSWORD=${VPN_PASSWORD:-}
APP_CMD="/usr/local/UniVPN/serviceclient/UniVPNCS"
DEBUG_MODE=${DEBUG_MODE:-false}

# Enable debug output if requested
if [ "$DEBUG_MODE" = "true" ]; then
    set -x
fi

# Helper function for logging with timestamp (outputs to stderr for Docker visibility)
log() {
    echo "[Keeper $(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Validation
if [ "$ENABLE" = "true" ]; then
    if [ -z "$VPN_USERNAME" ]; then
        log "ERROR: AUTO_RECONNECT is enabled but VPN_USERNAME is not set"
        exit 1
    fi
    
    if [ -z "$VPN_PASSWORD" ]; then
        log "ERROR: AUTO_RECONNECT is enabled but VPN_PASSWORD is not set"
        exit 1
    fi
fi

# Helper function to ensure a process is dead
ensure_stopped() {
    local pid=$1
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        log "Stopping VPN process (PID: $pid)..."
        kill "$pid" 2>/dev/null
        
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

# Function to check network connectivity
check_connectivity() {
    if ping -c 1 -W 2 "$TARGET" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

start_vpn() {
    log "Starting UniVPN connection..."
    
    local expect_log=""
    if [ "$DEBUG_MODE" = "true" ]; then
        expect_log="/tmp/univpn-expect-$(date +%s).log"
        log "Debug mode: expect output will be saved to $expect_log"
    fi
    
    # We use \[ and \] for visual tags so Tcl doesn't try to execute them
    # We use $VPN_USERNAME (bash variable) instead of $env to ensure it passes correctly
    
    expect ${expect_log:+-d} -c "
set timeout 30
log_user 1

${expect_log:+exp_internal -f \"$expect_log\" 1}

puts \"\[Keeper\] Spawning UniVPN client: $APP_CMD\"
spawn $APP_CMD

# 1. Wait for Welcome
expect {
    -re \".*Welcome.*UniVPN.*\" {
        puts \"\[Keeper\] ✓ Received welcome message\"
        send \"3\\r\"
    }
    timeout { puts \"\[Keeper\] ✗ Timeout on Welcome\"; exit 1 }
    eof { puts \"\[Keeper\] ✗ Process died early\"; exit 1 }
}

sleep 0.5

# 2. Wait for Menu
expect {
    -re \".*(1:Connect|Please select).*\" {
        puts \"\[Keeper\] ✓ Selecting Connect option\"
        send \"1\\r\"
    }
    timeout { puts \"\[Keeper\] ✗ Timeout on Menu\"; exit 1 }
}

sleep 0.5

# 3. Handle Login
expect {
    -re \".*login user name.*\" {
        puts \"\[Keeper\] → Entering username\"
        send \"$VPN_USERNAME\\r\"
        
        expect {
            -re \".*password.*\" {
                puts \"\[Keeper\] → Entering password\"
                send \"$VPN_PASSWORD\\r\"
            }
            timeout { puts \"\[Keeper\] ✗ Timeout on Password\"; exit 1 }
        }
    }
    -re \".*(Connect Success|Enjoy).*\" {
        puts \"\[Keeper\] ✓ Auto-connected (Stored Creds)\"
    }
    -re \".*Connecting.*\" {
        puts \"\[Keeper\] → Connecting...\"
    }
    timeout { puts \"\[Keeper\] ✗ Timeout waiting for login prompt\"; exit 1 }
}

# 4. Confirm Connection
expect {
    -re \".*(Connect Success|Enjoy).*\" {
        puts \"\[Keeper\] ✓✓✓ VPN CONNECTED SUCCESSFULLY ✓✓✓\"
    }
    -re \".*(failed|Failed|error|Error).*\" {
        puts \"\[Keeper\] ✗ Connection Failed\"
        exit 1
    }
    timeout { puts \"\[Keeper\] ✗ Timeout waiting for success message\"; exit 1 }
}

puts \"\[Keeper\] Connection established. Monitoring process...\"
puts \"\[Keeper\] =========================================\"

# --- FIX IS HERE ---
# Disable timeout so we wait forever for the process to run
set timeout -1

# Wait for the VPN process to close (which should be never, until we kill it)
expect eof
puts \"\[Keeper\] VPN process ended\"
" 2>&1
    
    local exit_code=$?
    
    if [ -n "$expect_log" ] && [ -f "$expect_log" ]; then
        log "Expect debug log available at: $expect_log"
    fi
    
    return $exit_code
}

# Cleanup any stray instances on start
log "========================================="
log "UniVPN Keeper Starting"
log "========================================="
log "Cleaning up any existing VPN processes..."
pkill -f "$APP_CMD" 2>/dev/null || true
sleep 2

# Main loop
while true; do
    log "========================================="
    log "Starting new VPN connection attempt"
    
    # Start VPN in background and capture PID
    start_vpn &
    VPN_PID=$!
    
    log "VPN process started with PID: $VPN_PID"
    
    if [ "$ENABLE" = "true" ]; then
        log "Auto-reconnect ENABLED"
        log "Target: $TARGET | Grace period: ${GRACE}s | Check interval: ${CHECK_INTERVAL}s"
        
        # Wait for initial connection establishment
        log "Waiting ${GRACE}s for VPN to establish connection..."
        sleep $GRACE
        
        # Check if process is still running after grace period
        if ! kill -0 $VPN_PID 2>/dev/null; then
            log "ERROR: VPN process died during startup. Retrying..."
            sleep $RETRY_DELAY
            continue
        fi
        
        log "Beginning health checks..."
        FAIL_COUNT=0
        
        # Monitor loop
        while kill -0 $VPN_PID 2>/dev/null; do
            if ! check_connectivity; then
                FAIL_COUNT=$((FAIL_COUNT + 1))
                log "WARNING: Ping check to $TARGET failed (attempt $FAIL_COUNT/2)"
                
                if [ $FAIL_COUNT -ge 2 ]; then
                    log "ERROR: Connection lost after 2 consecutive failures. Triggering restart..."
                    break
                fi
                
                sleep 2
            else
                # Reset fail count on success
                if [ $FAIL_COUNT -gt 0 ]; then
                    log "Connection restored"
                    FAIL_COUNT=0
                fi
                sleep $CHECK_INTERVAL
            fi
        done
        
        # Check if process died naturally
        if ! kill -0 $VPN_PID 2>/dev/null; then
            log "VPN process terminated unexpectedly"
        fi
        
    else
        log "Auto-reconnect DISABLED. Monitoring process only..."
        wait $VPN_PID
        EXIT_CODE=$?
        log "VPN process exited with code: $EXIT_CODE"
    fi
    
    # Ensure cleanup
    ensure_stopped $VPN_PID
    
    log "Waiting ${RETRY_DELAY}s before restart..."
    sleep $RETRY_DELAY
done
