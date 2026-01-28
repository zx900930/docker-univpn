#!/bin/bash
set -e

CONFIG_FILE="/home/vpnuser/UniVPN/sysconfig.ini"
KEEPER_SCRIPT="/usr/local/bin/univpn-keeper.sh"

echo "========================================="
echo "UniVPN Container Initialization"
echo "========================================="

# 1. Check if expect is installed
if ! command -v expect &> /dev/null; then
    echo "ERROR: 'expect' is not installed. Installing..."
    apt-get update && apt-get install -y expect
fi

# 2. Fix the config file to enable AutoLogin
if [ -f "$CONFIG_FILE" ]; then
    echo "Checking $CONFIG_FILE..."
    
    # Get the profile name
    TARGET_PROFILE=$(grep "^ClientLastAccessSession" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '[:space:]')
    
    if [ -n "$TARGET_PROFILE" ]; then
        # Find the section header for this profile
        SESSION_HEADER=$(awk -v target="$TARGET_PROFILE" '
            /^\[.*\]/ { header=$0 }
            $0 ~ "ProfileName *= *" target { print header; exit }
        ' "$CONFIG_FILE")
        
        if [ -n "$SESSION_HEADER" ]; then
            echo "Found target section: $SESSION_HEADER"
            # Escape brackets for sed
            ESCAPED_HEADER=$(echo "$SESSION_HEADER" | sed 's/\[/\\[/g; s/\]/\\]/g')
            # Replace AutoLogin=0 with 1 only inside that section
            sed -i "/^$ESCAPED_HEADER/,/^\[/ s/AutoLogin *= *0/AutoLogin = 1/" "$CONFIG_FILE"
            echo "✓ Updated AutoLogin to 1"
        else
            echo "⚠ Could not find session header for profile: $TARGET_PROFILE"
        fi
    else
        echo "⚠ No ClientLastAccessSession found in config"
    fi
else
    echo "⚠ Config file not found: $CONFIG_FILE"
    echo "  This is normal on first run. Config will be created after first manual connection."
fi

# 3. Display configuration
echo ""
echo "Configuration:"
echo "  AUTO_RECONNECT: ${AUTO_RECONNECT:-true}"
echo "  RECONNECT_PING_TARGET: ${RECONNECT_PING_TARGET:-8.8.8.8}"
echo "  RECONNECT_GRACE_PERIOD: ${RECONNECT_GRACE_PERIOD:-60}s"
echo "  HEALTH_CHECK_INTERVAL: ${HEALTH_CHECK_INTERVAL:-10}s"
echo "  VPN_USERNAME: ${VPN_USERNAME:+***set***}"
echo "  VPN_PASSWORD: ${VPN_PASSWORD:+***set***}"

# 4. Validate credentials if auto-reconnect is enabled
if [ "${AUTO_RECONNECT:-true}" = "true" ]; then
    if [ -z "$VPN_USERNAME" ] || [ -z "$VPN_PASSWORD" ]; then
        echo ""
        echo "ERROR: AUTO_RECONNECT is enabled but credentials are missing!"
        echo "Please set VPN_USERNAME and VPN_PASSWORD environment variables."
        exit 1
    fi
fi

echo "========================================="
echo "Starting UniVPN Keeper..."
echo "========================================="
echo ""

# 5. Execute the keeper script or custom command
if [ $# -eq 0 ]; then
    # No arguments provided, use default keeper script
    exec "$KEEPER_SCRIPT"
else
    # Custom command provided
    exec "$@"
fi
