# NVMe HAT Migration - Complete ✅

## Migration Status

**Date Completed**: December 21, 2024

✅ **node-0**: Successfully migrated to 128GB NVMe, booting from NVMe  
✅ **node-1**: Successfully migrated to 128GB NVMe, booting from NVMe  
✅ **PoE+ HAT**: Configured on both nodes  
✅ **Ansible**: Configured with SSH key authentication  
✅ **Hostnames**: node-0 and node-1 configured correctly

## Hardware Configuration

- **HAT**: M.2 NVMe M-key & PoE+ HAT
- **NVMe**: Kingston 128GB PCIe Gen4 NVMe (replacing 256GB SSD)
- **SD Card**: 64GB (used as backup boot option)
- **Boot Source**: NVMe (`/dev/nvme0n1p2`)
- **Boot Partition**: `/dev/nvme0n1p1` (511MB, mounted at `/boot/firmware`)

## Current Configuration

### Boot Configuration

Both nodes are configured to boot from NVMe with:
- **cmdline.txt**: `root=/dev/nvme0n1p2 rootfstype=ext4 rootwait rootdelay=5`
- **fstab**: Uses UUIDs for reliability:
  - Boot: `UUID=F587-071F` (node-0) / `UUID=F587-071F` (node-1)
  - Root: `UUID=4c4ea1b9-76db-4866-83fa-6b2b360e69e8` (node-0) / `UUID=217e1313-602b-475c-b5c0-7cd0a829ea49` (node-1)
- **rootdelay=5**: Added to give NVMe time to initialize before mounting root

### PoE+ Configuration

PoE+ HAT is configured on both nodes with fan temperature thresholds:
```
dtparam=poe_fan_temp0=50000
dtparam=poe_fan_temp1=60000
dtparam=poe_fan_temp2=70000
dtparam=poe_fan_temp3=80000
```

Location: `/boot/firmware/config.txt`

### Network Configuration

- **node-0**: 192.168.2.86 (control plane)
- **node-1**: 192.168.2.85 (worker)
- **Hostnames**: node-0.eldertree.local, node-1.eldertree.local

### Ansible Configuration

- **SSH Key**: `~/.ssh/id_ed25519_raolivei`
- **User**: `raolivei`
- **Inventory**: `pi-fleet/ansible/inventory/hosts.yml`
- **Config**: `pi-fleet/ansible/ansible.cfg`

## Verification

### Check Boot Status

```bash
# Verify booting from NVMe
ssh raolivei@node-0.eldertree.local "df -h / | tail -1"
# Should show: /dev/nvme0n1p2

ssh raolivei@node-1.eldertree.local "df -h / | tail -1"
# Should show: /dev/nvme0n1p2
```

### Check PoE+ Configuration

```bash
ansible all -m shell -a "sudo grep -c 'poe_fan' /boot/firmware/config.txt"
# Should return: 4 (for each node)
```

### Check Ansible Connectivity

```bash
cd pi-fleet/ansible
ansible all -m ping
# Should show SUCCESS for both nodes
```

## Issues Fixed During Migration

1. **Emergency Mode on Boot**: Fixed by:
   - Updating fstab to use UUIDs instead of device names
   - Adding `rootdelay=5` to cmdline.txt
   - Creating `/boot/firmware` directory in root filesystem

2. **Boot Configuration**: Ensured config.txt is present on NVMe boot partition

3. **Hostname**: Fixed node-1 hostname (was showing as "node-x")

## SD Card Status

SD cards remain as backup boot options. If NVMe boot fails, the system will fall back to SD card.

## Next Steps

1. ✅ **Migration Complete** - Both nodes booting from NVMe
2. ⏳ **K3s Installation** - K3s not yet installed (fresh install)
3. ⏳ **SD Card Switch** - Can now switch to backup SD cards
4. ⏳ **PoE+ Connection** - Connect nodes to PoE+ switch when ready

## Scripts Used

- `pi-fleet/scripts/storage/migrate-nvme-hat.sh` - Migration script
- `pi-fleet/scripts/storage/verify-nvme-migration.sh` - Verification script
- `pi-fleet/scripts/setup/configure-node-fresh-install.sh` - Fresh install configuration

## Documentation

- [Migration Quick Start](MIGRATION_NVME_HAT_QUICK_START.md)
- [Fresh Install Guide](FRESH_INSTALL_MIGRATION.md)
- [Secure Erase Guide](SECURE_ERASE_OLD_DRIVES.md)


