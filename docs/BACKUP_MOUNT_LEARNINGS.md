# Backup Mount - Lessons Learned

## The Problem

The `/dev/sdb1 /mnt/backup` mount was added by `setup-system.yml` as a "prepared" mount for optional USB backup drives. However:

1. **Not from Longhorn** - Longhorn uses `/mnt/longhorn-backup` (completely different)
2. **Not being used** - No scripts, no cron jobs, no actual backups
3. **Causes boot delays** - Even with `nofail`, systemd waits ~30s before giving up
4. **Default behavior** - Was added automatically to all nodes

## Trade-off Analysis

### Option 1: Keep Backup Mount (ON)
**Pros:**
- Prepared for when backup drive is connected
- Automatic mount when drive is available

**Cons:**
- **Boot timeout (~30s) on every boot** if drive not connected
- Slower boot times
- Unnecessary systemd unit waiting
- Clutters fstab with unused entries

**Verdict:** ❌ **Not worth it** - Boot delay is too high for unused feature

### Option 2: Remove Backup Mount (OFF - Default)
**Pros:**
- **Faster boot** - No timeouts
- Cleaner fstab
- No unnecessary systemd units

**Cons:**
- Need to configure manually when connecting backup drive
- One-time setup when needed

**Verdict:** ✅ **Recommended** - Boot speed > convenience of unused feature

## Decision

**Default: OFF** - Only enable when you have a permanently connected backup drive.

## Implementation Changes

### 1. Updated `setup-system.yml`
- Added `enable_backup_mount` variable (default: `false`)
- Only adds backup mount if explicitly enabled
- Removes existing backup mounts if disabled

### 2. Updated `fix-boot-reliability.yml`
- Now **removes** unused backup mount instead of just adding nofail
- Prevents boot timeouts

### 3. Created `remove-backup-mount.yml`
- Standalone playbook to remove backup mount from existing nodes

## Usage

**Default (no backup mount - recommended):**
```bash
ansible-playbook playbooks/setup-system.yml --limit node-0
```

**With backup mount (only if you have permanent USB drive):**
```bash
ansible-playbook playbooks/setup-system.yml --limit node-0 -e enable_backup_mount=true
```

## Fixing Existing Nodes

When recovering nodes, the backup mount will be automatically removed by `fix-boot-reliability.yml`.

To remove manually:
```bash
ansible-playbook playbooks/remove-backup-mount.yml
```

## Key Learnings

1. **Default behavior matters** - Don't add optional features by default
2. **Boot speed is critical** - Even "harmless" timeouts add up
3. **Document trade-offs** - Make decisions explicit
4. **Test assumptions** - Just because it has `nofail` doesn't mean it's harmless
5. **Question defaults** - Why is this mount here? Is it being used?

## Longhorn Backups

**Important**: This backup mount is NOT related to Longhorn. Longhorn has its own backup configuration at `/mnt/longhorn-backup` (configured via `backup-setup.sh`).

## Future Considerations

If you need backups:
1. **Use Longhorn backup target** - Already configured for Kubernetes workloads
2. **Configure backup mount manually** - When you actually connect a backup drive
3. **Use cloud backups** - For critical data
4. **Don't add by default** - Only when actually needed


