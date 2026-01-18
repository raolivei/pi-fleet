# Backup Mount Decision and Trade-off Analysis

## Problem

The `/dev/sdb1 /mnt/backup` mount in fstab was causing boot timeouts (~30 seconds) when the backup drive was not connected, even with `nofail` flag.

## Analysis

### What is the backup mount?

- **NOT from Longhorn** - Longhorn uses `/mnt/longhorn-backup` (different mount)
- **From `setup-system.yml`** - Added as optional USB backup drive mount
- **Purpose**: General system backups to external USB drive
- **Status**: Currently NOT being used (no scripts, no cron jobs)

### Trade-off Analysis

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| **ON (default)** | Prepared for backup drive<br>Automatic mount when connected | Boot timeout (~30s) if drive not connected<br>Slower boot times | ❌ Not recommended |
| **OFF (optional)** | Faster boot<br>No timeouts<br>Cleaner fstab | Need to configure manually when connecting drive | ✅ **Recommended** |

### Decision

**Default: OFF** - Only enable when you have a permanently connected backup drive.

## Implementation

### Updated Playbook

The `setup-system.yml` playbook now:
- **Default**: Does NOT add backup mount (`enable_backup_mount: false`)
- **Optional**: Can be enabled with `-e enable_backup_mount=true` if needed
- **Removes**: Existing backup mounts if disabled

### Usage

**Default (no backup mount):**
```bash
ansible-playbook playbooks/setup-system.yml --limit node-1
```

**With backup mount (if you have permanent USB drive):**
```bash
ansible-playbook playbooks/setup-system.yml --limit node-1 -e enable_backup_mount=true
```

## Fixing Existing Nodes

To remove backup mount from existing nodes:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook playbooks/remove-backup-mount.yml
```

Or manually:
```bash
sudo sed -i '/\/dev\/sdb1.*\/mnt\/backup/d' /etc/fstab
```

## When to Use Backup Mount

**Enable backup mount if:**
- You have a USB backup drive that is **permanently connected**
- You want automatic backups to that drive
- You're okay with ~30s boot timeout if drive disconnects

**Don't enable if:**
- No backup drive connected
- Drive is only connected occasionally
- You want fastest boot times
- You use Longhorn for backups (different mount)

## Longhorn Backups

**Note**: Longhorn has its own backup mount at `/mnt/longhorn-backup` (configured separately via `backup-setup.sh`). This is different from `/mnt/backup`.

## Lesson Learned

**Always consider boot impact of optional mounts:**
- Even with `nofail`, systemd waits before giving up
- Unused mounts cause unnecessary boot delays
- Make optional features truly optional (default OFF)
- Document trade-offs clearly


