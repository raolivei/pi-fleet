#!/bin/bash
# Fix SSH privilege separation directory issue
# This creates the directory with proper permissions and ensures it persists

set -e

echo "=== Fixing SSH Privilege Separation Directory ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Try different possible locations
POSSIBLE_DIRS=(
    "/run/ssh"
    "/var/run/ssh"
    "/run/sshd"
    "/var/run/sshd"
)

# Check which directory SSH expects
echo "Checking which directory SSH expects..."
SSHD_TEST=$(sshd -T 2>&1 | grep -i "privilege" || true)
echo "SSH daemon output: $SSHD_TEST"

# Create all possible directories
echo ""
echo "Creating privilege separation directories..."
for DIR in "${POSSIBLE_DIRS[@]}"; do
    if [ ! -d "$DIR" ]; then
        mkdir -p "$DIR"
        chmod 755 "$DIR"
        chown root:root "$DIR"
        echo "✓ Created $DIR"
    else
        echo "✓ $DIR already exists"
        chmod 755 "$DIR"
        chown root:root "$DIR"
    fi
done

# Also check what the actual sshd binary expects
echo ""
echo "Checking SSH configuration for PrivilegeSeparation setting..."
PRIVSEP_SETTING=$(sshd -T 2>&1 | grep -i "privilegeseparation" || echo "not found")
echo "PrivilegeSeparation setting: $PRIVSEP_SETTING"

# Check if there's a tmpfiles.d config
echo ""
echo "Checking for systemd tmpfiles configuration..."
if [ -f /etc/tmpfiles.d/ssh.conf ] || [ -f /usr/lib/tmpfiles.d/ssh.conf ]; then
    echo "Found tmpfiles config, ensuring it's correct..."
else
    echo "Creating tmpfiles.d configuration to ensure directory persists..."
    cat > /etc/tmpfiles.d/ssh.conf <<EOF
# SSH privilege separation directory
d /run/ssh 0755 root root -
EOF
    systemd-tmpfiles --create /etc/tmpfiles.d/ssh.conf
    echo "✓ Created tmpfiles.d configuration"
fi

# Now test SSH config
echo ""
echo "Testing SSH configuration..."
if sshd -t 2>&1; then
    echo "✓ SSH configuration test passed"
else
    echo "✗ SSH configuration test failed"
    sshd -t
    exit 1
fi

# Remove SendEnv if still present
echo ""
echo "Removing incorrect SendEnv line..."
sed -i '/^SendEnv/d' /etc/ssh/sshd_config
sed -i '/^#.*SendEnv/d' /etc/ssh/sshd_config

# Test again
echo ""
echo "Testing SSH configuration after SendEnv removal..."
if sshd -t 2>&1; then
    echo "✓ SSH configuration is valid"
else
    echo "✗ SSH configuration still has errors"
    sshd -t
    exit 1
fi

# Restart SSH
echo ""
echo "Restarting SSH service..."
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
sleep 2

# Verify
if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
    echo "✓ SSH service is running"
    echo ""
    echo "=== SSH is now fixed! ==="
else
    echo "✗ SSH service failed to start"
    systemctl status ssh || systemctl status sshd
    exit 1
fi

