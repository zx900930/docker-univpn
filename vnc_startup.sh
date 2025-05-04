#!/bin/bash
set -e

# --- START CLEANUP ---
# Use the display number derived from $DISPLAY
# Correct way to extract the number after the colon:
DISPLAY_NUM=${DISPLAY#:} # Removes the leading ':'
LOCK_FILE="/tmp/.X${DISPLAY_NUM}-lock"
SOCKET_FILE="/tmp/.X11-unix/X${DISPLAY_NUM}"
echo "[vnc_startup] Cleaning up stale files (if any) for display number ${DISPLAY_NUM}..."
rm -f "${LOCK_FILE}" "${SOCKET_FILE}"
rm -f "$HOME/.vnc/*:${DISPLAY_NUM}.log" "$HOME/.vnc/*:${DISPLAY_NUM}.pid"
echo "[vnc_startup] Cleanup finished."
# --- END CLEANUP ---


# --- START RUNTIME VERIFICATION ---
echo "[vnc_startup] Verifying vncpasswd existence at runtime..."
if [ ! -x "/usr/bin/vncpasswd" ]; then
    echo "[vnc_startup] ERROR: /usr/bin/vncpasswd not found or not executable at runtime!"
    ls -l /usr/bin/vnc* || echo "[vnc_startup] Failed to list /usr/bin/vnc*"
    echo "[vnc_startup] PATH is: $PATH"
    exit 1
fi
echo "[vnc_startup] /usr/bin/vncpasswd found."
# --- END RUNTIME VERIFICATION ---

# --- START PERMISSION/HOME DEBUG ---
echo "[vnc_startup] DEBUG: HOME variable is: $HOME"
echo "[vnc_startup] DEBUG: Permissions for parent dir ($HOME):"
ls -ld "$HOME" || echo "[vnc_startup] DEBUG: Failed to list $HOME"
echo "[vnc_startup] DEBUG: Attempting mkdir..."
# --- END PERMISSION/HOME DEBUG ---

# Create VNC config directory if it doesn't exist
mkdir -p "$HOME/.vnc"
echo "[vnc_startup] mkdir command finished. Checking existence:"
ls -ld "$HOME/.vnc" || echo "[vnc_startup] Failed to list $HOME/.vnc after mkdir"


# Set VNC password
echo "[vnc_startup] Setting VNC password..."
echo "$VNC_PW" | /usr/bin/vncpasswd -f > "$HOME/.vnc/passwd"
chmod 600 "$HOME/.vnc/passwd"
echo "[vnc_startup] VNC password set."

# --- Start VNC server using vncserver (runs in background) ---
echo "[vnc_startup] Starting VNC server on display ${DISPLAY} using vncserver command..."
# Calculate the RFB port number (should now work correctly)
RFB_PORT=$((5900 + DISPLAY_NUM))
echo "[vnc_startup] Calculated RFB port: ${RFB_PORT}" # Added debug message
/usr/bin/vncserver "${DISPLAY}" -localhost no -geometry "$VNC_RESOLUTION" -depth "$VNC_DEPTH" -SecurityTypes VncAuth -PasswordFile "$HOME/.vnc/passwd" -AlwaysShared -verbose -rfbport ${RFB_PORT}

# --- Keep script running and tail the log file ---
# Find the correct log file using the PORT number
LOG_FILE=""
COUNT=0
echo "[vnc_startup] Searching for log file matching pattern: $HOME/.vnc/*:${RFB_PORT}.log"
while [ -z "$LOG_FILE" ]; do
  # Use the port number in the pattern
  LOG_FILE=$(find "$HOME/.vnc/" -name "*:${RFB_PORT}.log" -print -quit)
  if [ -z "$LOG_FILE" ]; then
    sleep 1
    COUNT=$((COUNT+1))
    if [ ${COUNT} -gt 10 ]; then
        echo "[vnc_startup] ERROR: Could not find VNC log file matching *:${RFB_PORT}.log in $HOME/.vnc after 10 seconds."
        echo "[vnc_startup] Attempting to kill lingering VNC processes..."
        pkill -u "$(whoami)" -f "Xtigervnc .*:(${DISPLAY}|${RFB_PORT})" || echo "[vnc_startup] pkill command failed or no process found."
        exit 1
    fi
  fi
done

echo "[vnc_startup] Tailing VNC log file: $LOG_FILE"
# Use tail -F which handles file rotation/recreation
tail -F "$LOG_FILE" &
# Store tail PID
TAIL_PID=$!

# Wait indefinitely for tail to exit (e.g., if log file is deleted or container stops)
wait ${TAIL_PID}

echo "[vnc_startup] Tail process ended."
