#!/bin/bash
set -e

# Path to noVNC self.pem certificate (usually installed with novnc package)
CERT_PATH="/etc/ssl/certs/novnc.pem"

echo "Starting noVNC server on port 6901, proxying to localhost:5901"

websockify --web=/usr/share/novnc/ 6901 localhost:5901 --cert="${CERT_PATH}" --key="${CERT_PATH}"
