#!/bin/bash
set -e

CONFIG_FILE="/home/vpnuser/UniVPN/sysconfig.ini"

echo "--- Initializing Container ---"

# 1. FIX THE CONFIG FILE
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
            echo "Updated AutoLogin to 1."
        fi
    fi
else
    echo "Config file not found (yet). Skipping fix."
fi

# 2. START SUPERVISOR (or whatever command is passed to Docker)
echo "--- Starting Main Process ---"
exec "$@"
