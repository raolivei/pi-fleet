# Backup Strategy for Eldertree Cluster

This document describes the backup strategy and procedures for the eldertree Raspberry Pi k3s cluster.

## Overview

The backup system provides automated daily backups of:

- **PostgreSQL Databases** (swimTO, journey)
- **Vault Secrets** (all application secrets)
- **Kubernetes Resources** (deployments, services, configmaps, PVCs)
- **Persistent Volume Claims** (PVC data)
- **Configuration Files** (k3s config, fstab, network config)

## Backup Storage

- **Location**: USB drive mounted at `/mnt/backup`
- **Filesystem**: ext4 (formatted for Linux compatibility)
- **Capacity**: 60GB
- **Auto-mount**: Configured in `/etc/fstab` to mount on boot

## Backup Scripts

### `backup-all.sh`

Comprehensive backup script that backs up all cluster data.

**Usage:**

```bash
export KUBECONFIG=~/.kube/config-eldertree
~/backup-all.sh [backup-dir]
```

**Default backup directory**: `/mnt/backup`

**Backup Structure:**

```
/mnt/backup/backups/YYYYMMDD-HHMMSS/
├── databases/
│   ├── swimto-pools-YYYYMMDD-HHMMSS.sql.gz
│   └── journey-journey-YYYYMMDD-HHMMSS.sql.gz
├── vault/
│   └── vault-secrets-YYYYMMDD-HHMMSS.json
├── kubernetes/
│   ├── namespaces.json
│   ├── swimto/
│   ├── journey/
│   └── ...
├── pvcs/
│   ├── swimto-postgres-pvc-YYYYMMDD-HHMMSS.tar.gz
│   └── ...
├── configs/
│   ├── k3s.yaml
│   ├── fstab
│   └── ...
└── BACKUP_MANIFEST.txt
```

### `restore-all.sh`

Restore script for disaster recovery.

**Usage:**

```bash
export KUBECONFIG=~/.kube/config-eldertree
~/restore-all.sh /mnt/backup/backups/YYYYMMDD-HHMMSS
```

**⚠️ WARNING**: Restore will overwrite existing data! Always backup current state before restoring.

## Automated Backups

Backups run automatically via cron job:

- **Schedule**: Daily at 2:00 AM
- **Log File**: `~/backup.log`
- **Cron Entry**: `0 2 * * * export KUBECONFIG=~/.kube/config-eldertree && /home/raolivei/backup-all.sh /mnt/backup >> /home/raolivei/backup.log 2>&1`

**View cron jobs:**

```bash
ssh raolivei@eldertree.local 'crontab -l'
```

**View backup logs:**

```bash
ssh raolivei@eldertree.local 'tail -f ~/backup.log'
```

## Manual Backup

To run a backup manually:

```bash
ssh raolivei@eldertree.local
export KUBECONFIG=~/.kube/config-eldertree
~/backup-all.sh /mnt/backup
```

## Restore Procedures

### Restore PostgreSQL Database

```bash
# Restore swimTO database
export KUBECONFIG=~/.kube/config-eldertree
BACKUP_DIR="/mnt/backup/backups/YYYYMMDD-HHMMSS"

# Find postgres pod
POD=$(kubectl get pods -n swimto -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# Restore database
gunzip -c ${BACKUP_DIR}/databases/swimto-pools-*.sql.gz | \
  kubectl exec -i -n swimto ${POD} -- psql -U postgres pools
```

### Restore Vault Secrets

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Unseal Vault first
~/unseal-vault.sh

# Restore secrets
~/restore-vault-secrets.sh /mnt/backup/backups/YYYYMMDD-HHMMSS/vault/vault-secrets-*.json
```

### Restore PVC Data

```bash
export KUBECONFIG=~/.kube/config-eldertree
BACKUP_DIR="/mnt/backup/backups/YYYYMMDD-HHMMSS"

# Find pod using PVC
POD=$(kubectl get pods -n swimto -l app=postgres -o jsonpath='{.items[0].metadata.name}')
MOUNT_PATH="/var/lib/postgresql/data"

# Restore PVC
cat ${BACKUP_DIR}/pvcs/swimto-postgres-pvc-*.tar.gz | \
  kubectl exec -i -n swimto ${POD} -- tar xzf - -C ${MOUNT_PATH}
```

### Full Restore

Use the automated restore script:

```bash
export KUBECONFIG=~/.kube/config-eldertree
~/restore-all.sh /mnt/backup/backups/YYYYMMDD-HHMMSS
```

## Backup Retention

Currently, backups are kept indefinitely. Consider implementing retention policy:

```bash
# Keep only last 30 days of backups
find /mnt/backup/backups -type d -mtime +30 -exec rm -rf {} \;
```

Add to cron for automated cleanup:

```bash
0 3 * * * find /mnt/backup/backups -type d -mtime +30 -exec rm -rf {} \;
```

## Monitoring

### Check Backup Status

```bash
# List recent backups
ssh raolivei@eldertree.local 'ls -lht /mnt/backup/backups/ | head -10'

# Check backup size
ssh raolivei@eldertree.local 'du -sh /mnt/backup/backups/*'

# View latest backup manifest
ssh raolivei@eldertree.local 'cat /mnt/backup/backups/*/BACKUP_MANIFEST.txt | tail -20'
```

### Check Backup Logs

```bash
# View recent backup logs
ssh raolivei@eldertree.local 'tail -50 ~/backup.log'

# Check for errors
ssh raolivei@eldertree.local 'grep -i error ~/backup.log | tail -20'
```

## Troubleshooting

### USB Drive Not Mounted

```bash
# Check if USB drive is detected
lsblk | grep sdb

# Mount manually
sudo mount /dev/sdb1 /mnt/backup

# Check fstab entry
cat /etc/fstab | grep backup
```

**⚠️ Boot Failure Prevention**: If the system fails to boot because it's waiting for the USB drive, add the `nofail` option to the fstab entry:

```bash
# Edit fstab
sudo nano /etc/fstab

# Change from:
# /dev/sdb1 /mnt/backup ext4 defaults 0 2

# To:
# /dev/sdb1 /mnt/backup ext4 defaults,nofail 0 2
```

This allows the system to boot even if the USB drive isn't connected. See [Boot Fix Guide](./BOOT_FIX.md) for complete instructions.

### Backup Fails - Vault Sealed

Vault must be unsealed before backup can proceed:

```bash
export KUBECONFIG=~/.kube/config-eldertree
~/unseal-vault.sh
```

### Backup Fails - Pod Not Found

Check if pods are running:

```bash
kubectl get pods --all-namespaces
```

If pods are not running, backups will skip those resources (this is expected behavior).

### Insufficient Space

Check available space:

```bash
df -h /mnt/backup
```

Clean up old backups if needed:

```bash
# Remove backups older than 30 days
find /mnt/backup/backups -type d -mtime +30 -exec rm -rf {} \;
```

## Backup Verification

### Verify Backup Integrity

```bash
# Check backup files exist
ls -lh /mnt/backup/backups/YYYYMMDD-HHMMSS/*/

# Verify database backup
gunzip -t /mnt/backup/backups/YYYYMMDD-HHMMSS/databases/*.sql.gz

# Verify Vault backup (JSON format)
jq . /mnt/backup/backups/YYYYMMDD-HHMMSS/vault/*.json > /dev/null

# Verify PVC backup
file /mnt/backup/backups/YYYYMMDD-HHMMSS/pvcs/*.tar.gz
```

## Best Practices

1. **Test Restores**: Periodically test restore procedures to ensure backups are valid
2. **Monitor Logs**: Check backup logs regularly for errors
3. **Offsite Backup**: Consider copying critical backups to another location
4. **Document Changes**: Update this document when backup procedures change
5. **Verify After Changes**: Test backups after any infrastructure changes

## Related Scripts

- `backup-vault-secrets.sh` - Vault-specific backup
- `restore-vault-secrets.sh` - Vault-specific restore
- `unseal-vault.sh` - Unseal Vault (required before backup)

## References

- [Kubernetes Backup Best Practices](https://kubernetes.io/docs/tasks/administer-cluster/backup/)
- [PostgreSQL Backup and Restore](https://www.postgresql.org/docs/current/backup.html)
- [Vault Backup and Restore](https://developer.hashicorp.com/vault/docs/operations/backup)
