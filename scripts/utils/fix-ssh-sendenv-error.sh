#!/bin/bash
# Fix SSH SendEnv configuration error
# This removes the incorrect SendEnv line from /etc/ssh/sshd_config
# SendEnv is a client-side option, not server-side

set -e

echo "=== Fixing SSH SendEnv Configuration Error ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

SSH_CONFIG="/etc/ssh/sshd_config"
BACKUP="${SSH_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"

# Create backup
echo "Creating backup: $BACKUP"
cp "$SSH_CONFIG" "$BACKUP"

# Remove SendEnv line from server config
echo "Removing incorrect SendEnv line from server config..."
sed -i '/^SendEnv/d' "$SSH_CONFIG"
sed -i '/^#.*SendEnv/d' "$SSH_CONFIG"

# Test SSH config
echo ""
echo "Testing SSH configuration..."
if sshd -t; then
    echo "✓ SSH configuration is valid"
else
    echo "✗ SSH configuration still has errors!"
    echo "Restoring backup..."
    cp "$BACKUP" "$SSH_CONFIG"
    exit 1
fi

# Restart SSH service
echo ""
echo "Restarting SSH service..."
if systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null; then
    echo "✓ SSH service restarted"
else
    echo "✗ Failed to restart SSH service"
    systemctl status ssh || systemctl status sshd
    exit 1
fi

# Verify SSH is running
echo ""
echo "Verifying SSH service..."
sleep 2
if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
    echo "✓ SSH service is running"
    echo ""
    echo "SSH is now fixed and accessible!"
else
    echo "✗ SSH service is not running"
    systemctl status ssh || systemctl status sshd
    exit 1
fi

