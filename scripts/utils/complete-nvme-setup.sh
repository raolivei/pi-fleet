#!/bin/bash
# Complete NVMe setup by providing all confirmations

set -e

NODE1_IP="192.168.2.85"
USER="raolivei"

echo "=== Completing NVMe Boot Setup on node-1 ==="
echo ""

# Create a script that will answer all prompts
ssh ${USER}@${NODE1_IP} << 'ENDSSH'
cd ~

# Create a wrapper script that answers all prompts
cat > /tmp/run-nvme-setup-auto.sh << 'EOF'
#!/bin/bash
# Auto-answer script for NVMe setup

echo "y" | sudo ./setup-nvme-boot.sh << ANSWERS
y
y
y
ANSWERS
EOF

chmod +x /tmp/run-nvme-setup-auto.sh

# Run it
cd ~ && /tmp/run-nvme-setup-auto.sh 2>&1 | tee /tmp/nvme-setup-final.log

echo ""
echo "Setup complete! Check /tmp/nvme-setup-final.log for details"
ENDSSH

echo ""
echo "✓ Setup initiated"
echo ""
echo "To monitor progress:"
echo "  ssh ${USER}@${NODE1_IP} 'tail -f /tmp/nvme-setup-final.log'"
echo ""
echo "This will take 10-30 minutes to complete."

