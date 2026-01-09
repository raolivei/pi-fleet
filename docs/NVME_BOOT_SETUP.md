# NVMe Boot Setup Guide

Complete guide for setting up Raspberry Pi 5 to boot from NVMe drive using the `setup-nvme-boot.yml` Ansible playbook.

## Overview

The `setup-nvme-boot.yml` playbook provides a comprehensive, **idempotent** solution for configuring NVMe boot on Raspberry Pi 5 nodes. It handles:

- Partition creation (GPT, boot, root)
- Filesystem formatting
- OS cloning from SD card
- Emergency mode prevention
- Boot configuration

## Key Features

### ✅ Idempotency

The playbook is **safe to run multiple times** on working nodes:

- **Skips partition creation** if partitions already exist and are in use
- **Skips formatting** if partitions are already formatted
- **Skips cloning** if root partition already has content
- **Only performs necessary operations**

This makes it safe to re-run the playbook for configuration updates without risking data loss.

### ✅ Emergency Mode Prevention

Automatically applies comprehensive fixes to prevent emergency mode:

- **Clean fstab**: Creates proper fstab with correct NVMe PARTUUIDs (no duplicates, no problematic entries)
- **Clean cmdline.txt**: Ensures correct root device (`/dev/nvme0n1p2`) and cgroup settings
- **Root account unlocked**: Unlocks root and sets password to prevent console lock
- **PAM faillock disabled**: Prevents account lockouts that block emergency mode access
- **Password expiration disabled**: Prevents account expiration issues

### ✅ Partition Protection

- Detects if partitions are mounted/in use
- Prevents operations on mounted partitions (unless `force_repartition=true`)
- Warns before destructive operations

## Prerequisites

1. **Raspberry Pi 5** with NVMe drive installed
2. **SD card** with OS installed (for cloning)
3. **Ansible** configured with SSH access to the node
4. **Node booted from SD card** (not NVMe yet)

## Basic Usage

### Standard Setup (New Node)

For a new node that needs NVMe boot setup:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible

ansible-playbook playbooks/setup-nvme-boot.yml \
  --limit node-X \
  -e "setup_nvme_boot=true" \
  -e "clone_from_sd=true"
```

**What this does**:

1. Checks if already booting from NVMe (skips if yes)
2. Checks if partitions exist
3. Creates partitions if they don't exist
4. Formats partitions if not already formatted
5. Clones OS from SD card to NVMe
6. Applies emergency mode prevention fixes
7. Configures boot settings

### Re-running on Working Node (Idempotent)

Safe to run on nodes that already have NVMe setup:

```bash
ansible-playbook playbooks/setup-nvme-boot.yml \
  --limit node-X \
  -e "setup_nvme_boot=true"
```

**What happens**:

- Detects existing partitions
- Detects mounted partitions
- Skips partition creation (partitions exist and are in use)
- Skips formatting (partitions already formatted)
- Skips cloning (root partition has content)
- Only applies configuration updates if needed

### Force Repartitioning (⚠️ Destructive)

**WARNING**: This will erase all data on NVMe!

Only use if you need to recreate partitions:

```bash
ansible-playbook playbooks/setup-nvme-boot.yml \
  --limit node-X \
  -e "setup_nvme_boot=true" \
  -e "force_repartition=true"
```

**What this does**:

1. Unmounts all NVMe partitions
2. Destroys existing partition table
3. Creates new partitions
4. Formats partitions
5. Clones OS (if `clone_from_sd=true`)

## Variables

### Required Variables

- `setup_nvme_boot`: Enable NVMe boot setup (default: `false`)
  ```yaml
  -e "setup_nvme_boot=true"
  ```

### Optional Variables

- `clone_from_sd`: Clone OS from SD card (default: `true`)
  ```yaml
  -e "clone_from_sd=true"  # Clone OS from SD card
  -e "clone_from_sd=false"  # Skip cloning (partitions only)
  ```

- `force_repartition`: Force repartitioning (⚠️ **destructive**, default: `false`)
  ```yaml
  -e "force_repartition=true"  # Force repartitioning (erases all data)
  ```

- `target_password`: Root password for emergency mode (from vault or env var)
  ```yaml
  -e "target_password=<password>"  # Or use PI_PASSWORD env var
  ```

- `boot_partition_size`: Boot partition size (default: `1024MiB`)
  ```yaml
  -e "boot_partition_size=1024MiB"
  ```

- `root_partition_size`: Root partition size (default: `30GiB`)
  ```yaml
  -e "root_partition_size=30GiB"
  ```

- `create_storage_partition`: Create additional storage partition (default: `false`)
  ```yaml
  -e "create_storage_partition=true"
  ```

## Playbook Behavior

### Partition Detection

The playbook checks:

1. **Partition count**: How many partitions exist on NVMe
2. **Partition existence**: Whether specific partitions (p1, p2) exist
3. **Mount status**: Whether partitions are mounted/in use
4. **Filesystem status**: Whether partitions are formatted

### Decision Logic

**Partition Creation**:
- Creates if: partitions don't exist OR `force_repartition=true`
- Skips if: partitions exist AND are in use AND `force_repartition=false`

**Formatting**:
- Formats if: partition not formatted OR `force_repartition=true`
- Skips if: partition already formatted AND `force_repartition=false`

**Cloning**:
- Clones if: `clone_from_sd=true` AND root partition is empty
- Skips if: root partition already has content

## Verification

### Check Partition Status

```bash
ansible node-X -i ansible/inventory/hosts.yml \
  -m shell -a "lsblk | grep nvme" --become
```

**Expected output**:
```
nvme0n1     259:0    0 119.2G  0 disk
├─nvme0n1p1 259:1    0   511M  0 part /boot/firmware
└─nvme0n1p2 259:2    0  30.0G  0 part /
```

### Check Boot Configuration

```bash
ansible node-X -i ansible/inventory/hosts.yml \
  -m shell -a "sudo mount /dev/nvme0n1p1 /mnt/nvme-boot && sudo cat /mnt/nvme-boot/cmdline.txt && sudo umount /mnt/nvme-boot" --become
```

**Expected output**:
```
console=serial0,115200 console=tty1 root=/dev/nvme0n1p2 rootfstype=ext4 rootwait rootdelay=5 cgroup_memory=1 cgroup_enable=memory systemd.unified_cgroup_hierarchy=0 quiet splash
```

### Check if Booting from NVMe

```bash
ansible node-X -i ansible/inventory/hosts.yml \
  -m shell -a "df -h / | tail -1" --become
```

**Expected output** (after reboot):
```
/dev/nvme0n1p2   30G  2.0G   26G   8% /
```

## Troubleshooting

### Partitions Already Exist and Are In Use

**Error**: `Error: Partition(s) on /dev/nvme0n1 are being used.`

**Solution**: This is expected behavior! The playbook detected that partitions exist and are mounted. This means:

- ✅ The node is already set up correctly
- ✅ The playbook is working as designed (idempotent)
- ✅ No action needed - partitions are protected

If you need to recreate partitions, use `force_repartition=true` (⚠️ **WARNING: This will erase all data**).

### Node Boots from SD Card Instead of NVMe

1. **Check cmdline.txt**:
   ```bash
   ansible node-X -i ansible/inventory/hosts.yml \
     -m shell -a "sudo mount /dev/nvme0n1p1 /mnt/nvme-boot && sudo cat /mnt/nvme-boot/cmdline.txt | grep 'root=/dev/nvme0n1p2' && sudo umount /mnt/nvme-boot" --become
   ```

2. **Re-run playbook** (idempotent, safe):
   ```bash
   ansible-playbook playbooks/setup-nvme-boot.yml \
     --limit node-X \
     -e "setup_nvme_boot=true"
   ```

3. **Remove SD card** and reboot

### Emergency Mode on Boot

If the node boots into emergency mode:

1. **Check fstab**:
   ```bash
   ansible node-X -i ansible/inventory/hosts.yml \
     -m shell -a "sudo cat /etc/fstab" --become
   ```

2. **Re-run playbook** to apply emergency mode prevention fixes:
   ```bash
   ansible-playbook playbooks/setup-nvme-boot.yml \
     --limit node-X \
     -e "setup_nvme_boot=true"
   ```

The playbook will apply all emergency mode prevention fixes automatically.

## Best Practices

1. **Always run idempotently**: Don't use `force_repartition=true` unless absolutely necessary
2. **Verify before force**: Check partition status before forcing repartitioning
3. **Backup important data**: Before using `force_repartition=true`, ensure you have backups
4. **Test on non-critical nodes**: Test playbook changes on development nodes first
5. **Monitor playbook output**: Review what the playbook will do before confirming destructive operations

## Related Documentation

- [SETUP_NODE_2_PROMPT.md](SETUP_NODE_2_PROMPT.md) - Complete node setup guide
- [EMERGENCY_MODE_RECOVERY.md](EMERGENCY_MODE_RECOVERY.md) - Emergency mode troubleshooting
- [NVME_BOOT_TROUBLESHOOTING.md](NVME_BOOT_TROUBLESHOOTING.md) - Additional troubleshooting

## Summary

The `setup-nvme-boot.yml` playbook provides a safe, idempotent way to configure NVMe boot on Raspberry Pi 5 nodes. It:

- ✅ Protects existing partitions and data
- ✅ Prevents emergency mode issues
- ✅ Can be safely run multiple times
- ✅ Only performs necessary operations
- ✅ Provides clear warnings for destructive operations

Use it with confidence for both new node setup and configuration updates on existing nodes.
