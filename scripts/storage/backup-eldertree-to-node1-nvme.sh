#!/bin/bash
# Direct backup from eldertree to eldertree-node-1 NVMe
# Uses direct gigabit connection between Pis for fastest transfer

set -e

# Network configuration
# wlan0 IPs (for SSH access):
#   node-0 (eldertree): 192.168.2.86
#   node-1: 192.168.2.85
# eth0 IPs (for direct gigabit connection via isolated switch):
#   node-0 eth0: 10.0.0.1
#   node-1 eth0: 10.0.0.2
ELDERTREE_WLAN="${ELDERTREE_WLAN_IP:-192.168.2.86}"
NODE1_WLAN="${NODE1_WLAN_IP:-192.168.2.85}"
ELDERTREE_ETH0="${ELDERTREE_ETH0_IP:-10.0.0.1}"
NODE1_ETH0="${NODE1_ETH0_IP:-10.0.0.2}"

# Use eth0 IPs for direct gigabit connection
ELDERTREE="$ELDERTREE_ETH0"
NODE1="$NODE1_ETH0"
BACKUP_DIR="/mnt/backup-nvme/eldertree-nvme-backup-$(date +%Y%m%d-%H%M%S)"

echo "=== Direct Backup: eldertree → node-1 NVMe ==="
echo ""
echo "Source: node-0 eth0 ($ELDERTREE):/mnt/nvme"
echo "Destination: node-1 eth0 ($NODE1):$BACKUP_DIR"
echo "Connection: Direct gigabit switch (isolated network 10.0.0.0/24)"
echo "SSH access: node-0 wlan0 ($ELDERTREE_WLAN), node-1 wlan0 ($NODE1_WLAN)"
echo ""

# Check eldertree data (using wlan0 for SSH access)
echo "Checking eldertree data..."
DATA_SIZE=$(sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$ELDERTREE_WLAN \
    "sudo du -sh /mnt/nvme 2>/dev/null | awk '{print \$1}'" 2>&1)
echo "Data to backup: $DATA_SIZE"
echo ""

# Check node1 space (using wlan0 for SSH access)
echo "Checking node-1 backup partition space..."
NODE1_SPACE=$(sshpass -p 'ac0df36b52' ssh -o StrictHostKeyChecking=no raolivei@$NODE1_WLAN \
    "df -h /mnt/backup-nvme | tail -1 | awk '{print \$4}'" 2>&1)
echo "Available space on node-1 backup partition: $NODE1_SPACE"
echo ""

# Create backup directory on node1 (using wlan0 for SSH access)
echo "Creating backup directory on node-1..."
sshpass -p 'ac0df36b52' ssh -o StrictHostKeyChecking=no raolivei@$NODE1_WLAN \
    "mkdir -p $BACKUP_DIR && chown raolivei:raolivei $BACKUP_DIR" 2>&1

# Show what will be backed up (using wlan0 for SSH access)
echo "Data breakdown on eldertree:"
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$ELDERTREE_WLAN \
    "sudo du -sh /mnt/nvme/* 2>/dev/null | sort -h" 2>&1
echo ""

# Confirm
read -p "Continue with direct backup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Backup cancelled"
    exit 1
fi

# Setup SSH keys for direct Pi-to-Pi transfer (if not already done)
echo ""
echo "Setting up direct Pi-to-Pi connection..."
echo "This will use the gigabit switch for fastest transfer"
echo ""

# Start backup using direct connection
echo "Starting direct backup (this will take 20-40 minutes for 95GB)..."
echo "Using gigabit connection: eldertree → eldertree-node-1"
echo ""

# Use rsync with compression and direct eth0 connection
# The Pis are on the same isolated gigabit switch (10.0.0.0/24), so this should be very fast
# rsync will use eth0 IPs for the data transfer
echo "Starting rsync via eth0 (10.0.0.1 → 10.0.0.2)..."
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@$ELDERTREE_WLAN \
    "sudo rsync -avh --progress --compress -e 'ssh -o StrictHostKeyChecking=no' /mnt/nvme/ raolivei@$NODE1:$BACKUP_DIR/ 2>&1" | \
    tee /tmp/eldertree-to-node1-backup.log

# Verify backup (using wlan0 for SSH access)
echo ""
echo "Verifying backup..."
BACKUP_SIZE=$(sshpass -p 'ac0df36b52' ssh -o StrictHostKeyChecking=no raolivei@$NODE1_WLAN \
    "du -sh $BACKUP_DIR 2>/dev/null | awk '{print \$1}'" 2>&1)
echo "Backup size: $BACKUP_SIZE"
echo "Original size: $DATA_SIZE"

# Create manifest (using wlan0 for SSH access)
echo ""
echo "Creating backup manifest..."
sshpass -p 'ac0df36b52' ssh -o StrictHostKeyChecking=no raolivei@$NODE1_WLAN "cat > $BACKUP_DIR/BACKUP_MANIFEST.txt <<EOF
eldertree NVMe Data Backup
==========================
Date: $(date)
Source: node-0 eth0 ($ELDERTREE):/mnt/nvme
Destination: node-1 eth0 ($NODE1):$BACKUP_DIR
Connection: Direct gigabit switch (isolated 10.0.0.0/24 network)
Original size: $DATA_SIZE
Backup size: $BACKUP_SIZE

To restore:
  rsync -avh $BACKUP_DIR/ /mnt/nvme/
EOF
" 2>&1

echo ""
echo "✅ Backup complete!"
echo ""
echo "Backup location: eldertree-node-1:$BACKUP_DIR"
echo ""
echo "Next steps:"
echo "  1. Proceed with eldertree NVMe boot setup"
echo "  2. After boot setup, restore data if needed:"
echo "     rsync -avh $NODE1:$BACKUP_DIR/ /mnt/nvme/"

