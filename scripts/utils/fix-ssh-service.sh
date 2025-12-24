#!/bin/bash
# Fix SSH service on a node
# This script should be run with physical access or via another method
# Usage: Run on the node directly (not via SSH)

set -e

echo "=== Fixing SSH Service ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Check SSH service name
if systemctl list-units --type=service | grep -q '^ssh\.service'; then
    SSH_SERVICE="ssh"
elif systemctl list-units --type=service | grep -q '^sshd\.service'; then
    SSH_SERVICE="sshd"
else
    echo "Error: Could not find SSH service"
    exit 1
fi

echo "Found SSH service: $SSH_SERVICE"
echo ""

# Check SSH config for syntax errors
echo "Checking SSH configuration..."
if sshd -t; then
    echo "✓ SSH configuration is valid"
else
    echo "✗ SSH configuration has errors!"
    echo "Checking /etc/ssh/sshd_config for issues..."
    sshd -T | grep -E "error|invalid" || true
    echo ""
    echo "You may need to restore a backup or fix the configuration manually"
    exit 1
fi

# Try to start SSH service
echo ""
echo "Starting SSH service..."
if systemctl start "$SSH_SERVICE"; then
    echo "✓ SSH service started"
else
    echo "✗ Failed to start SSH service"
    echo ""
    echo "Checking service status:"
    systemctl status "$SSH_SERVICE" --no-pager || true
    echo ""
    echo "Checking logs:"
    journalctl -u "$SSH_SERVICE" -n 20 --no-pager || true
    exit 1
fi

# Enable SSH service
echo "Enabling SSH service..."
systemctl enable "$SSH_SERVICE"
echo "✓ SSH service enabled"

# Verify SSH is running
echo ""
echo "Verifying SSH service status..."
if systemctl is-active --quiet "$SSH_SERVICE"; then
    echo "✓ SSH service is running"
    echo ""
    echo "SSH should now be accessible"
else
    echo "✗ SSH service is not running"
    systemctl status "$SSH_SERVICE" --no-pager
    exit 1
fi

