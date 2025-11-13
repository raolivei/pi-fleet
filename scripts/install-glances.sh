#!/bin/bash
# Install Glances on Raspberry Pi host
# This script SSHs into the Raspberry Pi and installs Glances with a systemd service

set -e

# Source terraform variables if terraform.tfvars exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TFVARS_FILE="$PROJECT_ROOT/terraform/terraform.tfvars"

if [ ! -f "$TFVARS_FILE" ]; then
    echo "Error: terraform.tfvars not found at $TFVARS_FILE"
    echo "Please create terraform.tfvars from terraform.tfvars.example"
    exit 1
fi

# Extract variables from terraform.tfvars
PI_HOST=$(grep '^pi_host' "$TFVARS_FILE" | awk '{print $3}' | tr -d '"')
PI_USER=$(grep '^pi_user' "$TFVARS_FILE" | awk '{print $3}' | tr -d '"')
PI_PASSWORD=$(grep '^pi_password' "$TFVARS_FILE" | awk '{print $3}' | tr -d '"')

if [ -z "$PI_HOST" ] || [ -z "$PI_USER" ] || [ -z "$PI_PASSWORD" ]; then
    echo "Error: Could not extract pi_host, pi_user, or pi_password from terraform.tfvars"
    exit 1
fi

echo "Installing Glances on $PI_USER@$PI_HOST..."

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo "Error: sshpass is not installed. Install it with: brew install hudochenkov/sshpass/sshpass"
    exit 1
fi

# SSH into Raspberry Pi and install Glances
sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$PI_USER@$PI_HOST" bash << ENDSSH
set -e

PASSWORD="$PI_PASSWORD"
HOSTNAME="$PI_HOST"

echo "Updating package list..."
echo "\$PASSWORD" | sudo -S apt-get update -qq

echo "Installing Glances..."
# Try apt first, fallback to pip if not available
if echo "\$PASSWORD" | sudo -S apt-get install -y glances 2>/dev/null; then
    echo "Glances installed via apt"
else
    echo "apt package not available, installing via pip..."
    echo "\$PASSWORD" | sudo -S apt-get install -y python3-pip python3-dev
    echo "\$PASSWORD" | sudo -S pip3 install glances
fi

echo "Creating systemd service for Glances..."
cat << 'EOF' | sudo tee /etc/systemd/system/glances.service > /dev/null
[Unit]
Description=Glances - An eye on your system
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/glances -w --bind 0.0.0.0 --port 61208
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd and enabling Glances service..."
sudo systemctl daemon-reload
sudo systemctl enable glances.service
sudo systemctl restart glances.service

echo "Checking Glances status..."
sleep 2
sudo systemctl status glances.service --no-pager || true

echo ""
echo "Glances installed successfully!"
echo "Access Glances web UI at: http://\$HOSTNAME:61208"
echo "Or check status with: sudo systemctl status glances"
ENDSSH

echo ""
echo "Glances installation completed!"
echo "Access Glances web UI at: http://$PI_HOST:61208"

