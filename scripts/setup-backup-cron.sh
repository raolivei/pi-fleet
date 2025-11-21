#!/bin/bash
set -e

# Setup automated backups via cron job
# This script configures daily backups at 2 AM

BACKUP_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_SCRIPT="${BACKUP_SCRIPT_DIR}/backup-all.sh"
CRON_SCHEDULE="0 2 * * *"  # Daily at 2 AM
BACKUP_DIR="/mnt/backup"

echo "=== Setting up automated backups ==="
echo ""

# Check if running on the Pi
if ! sshpass -p 'Control01!' ssh -o ConnectTimeout=5 raolivei@eldertree.local "echo 'Connected'" &>/dev/null; then
    echo "❌ Cannot connect to eldertree.local"
    echo "Please run this script from a machine that can SSH to the Pi"
    exit 1
fi

# Copy backup script to Pi
echo "📋 Copying backup script to Pi..."
sshpass -p 'Control01!' scp "${BACKUP_SCRIPT}" raolivei@eldertree.local:~/backup-all.sh

# Setup cron job on Pi
echo "⏰ Setting up cron job..."
sshpass -p 'Control01!' ssh raolivei@eldertree.local << 'EOF'
# Create backup directory if it doesn't exist
sudo mkdir -p /mnt/backup/backups
sudo chown -R raolivei:raolivei /mnt/backup

# Make script executable
chmod +x ~/backup-all.sh

# Add cron job if it doesn't exist
(crontab -l 2>/dev/null | grep -v "backup-all.sh"; echo "0 2 * * * /home/raolivei/backup-all.sh /mnt/backup >> /home/raolivei/backup.log 2>&1") | crontab -

echo "✅ Cron job configured:"
crontab -l | grep backup-all.sh
EOF

echo ""
echo "✅ Automated backups configured!"
echo ""
echo "Backup schedule: Daily at 2:00 AM"
echo "Backup location: ${BACKUP_DIR}/backups/"
echo "Log file: ~/backup.log"
echo ""
echo "To test backup manually:"
echo "  ssh raolivei@eldertree.local '~/backup-all.sh /mnt/backup'"
echo ""
echo "To view cron jobs:"
echo "  ssh raolivei@eldertree.local 'crontab -l'"

