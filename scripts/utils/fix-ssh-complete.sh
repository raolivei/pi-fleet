#!/bin/bash
# Complete SSH fix script
# Fixes SendEnv error and missing privilege separation directory

set -e

echo "=== Complete SSH Fix ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

SSH_CONFIG="/etc/ssh/sshd_config"
SSH_RUN_DIR="/run/ssh"

# Step 1: Create privilege separation directory
echo "Step 1: Creating privilege separation directory..."
if [ ! -d "$SSH_RUN_DIR" ]; then
    mkdir -p "$SSH_RUN_DIR"
    chmod 755 "$SSH_RUN_DIR"
    echo "✓ Created $SSH_RUN_DIR"
else
    echo "✓ Directory already exists"
fi

# Step 2: Remove incorrect SendEnv line
echo ""
echo "Step 2: Removing incorrect SendEnv line from server config..."
BACKUP="${SSH_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"
cp "$SSH_CONFIG" "$BACKUP"
echo "Backup created: $BACKUP"

# Remove SendEnv lines
sed -i '/^SendEnv/d' "$SSH_CONFIG"
sed -i '/^#.*SendEnv/d' "$SSH_CONFIG"
echo "✓ Removed SendEnv lines"

# Step 3: Test SSH config
echo ""
echo "Step 3: Testing SSH configuration..."
if sshd -t; then
    echo "✓ SSH configuration is valid"
else
    echo "✗ SSH configuration still has errors!"
    echo "Restoring backup..."
    cp "$BACKUP" "$SSH_CONFIG"
    exit 1
fi

# Step 4: Restart SSH service
echo ""
echo "Step 4: Restarting SSH service..."
if systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null; then
    echo "✓ SSH service restarted"
else
    echo "✗ Failed to restart SSH service"
    systemctl status ssh || systemctl status sshd || true
    exit 1
fi

# Step 5: Verify SSH is running
echo ""
echo "Step 5: Verifying SSH service..."
sleep 2
if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
    echo "✓ SSH service is running"
    echo ""
    echo "=== SSH is now fixed and accessible! ==="
else
    echo "✗ SSH service is not running"
    echo ""
    echo "Checking status:"
    systemctl status ssh || systemctl status sshd || true
    exit 1
fi

