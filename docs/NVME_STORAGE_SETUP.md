# NVMe SSD Storage Setup for Eldertree Cluster

## Overview

The eldertree Raspberry Pi has a 256GB NVMe SSD (via M.2 adapter) that should be used for high-performance storage needs. This document describes the recommended storage strategy and setup procedures.

## Current Storage Situation

- **SD Card (mmcblk0)**: 59.5GB total, ~8.1GB used (15%)
  - Boot partition: `/boot/firmware` (512MB)
  - Root filesystem: `/` (58GB)
  - K3s data: `/var/lib/rancher/k3s/` (~1.1GB)
  
- **NVMe SSD (nvme0n1)**: 238.5GB, currently unpartitioned and unused
  - Device: `/dev/nvme0n1`
  - Model: SSD 256GB

- **USB Backup Drive**: 60GB at `/mnt/backup` (for backups only)

## Recommended Storage Strategy

### 1. **K3s Data Directory** → NVMe SSD
   - **Location**: `/mnt/nvme/k3s`
   - **Contents**: 
     - Container images (`/var/lib/rancher/k3s/agent/containerd/`)
     - K3s server data (`/var/lib/rancher/k3s/server/`)
     - K3s agent data (`/var/lib/rancher/k3s/agent/`)
   - **Benefits**: 
     - Faster container image pulls
     - Faster container startup times
     - Reduced SD card wear
     - Better performance for etcd/SQLite operations

### 2. **Persistent Volumes (PVCs)** → NVMe SSD
   - **Location**: `/mnt/nvme/storage` (for local-path provisioner)
   - **Contents**: All PVC data (PostgreSQL, Vault, Pi-hole, etc.)
   - **Benefits**:
     - Much faster database I/O
     - Better performance for stateful workloads
     - Reduced SD card wear

### 3. **Keep on SD Card**
   - Boot partition (required)
   - Root filesystem (system files)
   - Logs (unless you want to move them)
   - Temporary files

### 4. **Backups** → USB Drive (unchanged)
   - Keep backups on separate USB drive at `/mnt/backup`
   - This provides physical separation for disaster recovery

## Storage Layout

```
NVMe SSD (256GB) - /mnt/nvme
├── k3s/                    # K3s data directory (symlinked from /var/lib/rancher/k3s)
│   ├── agent/
│   │   └── containerd/     # Container images
│   ├── server/             # K3s server data
│   └── data/               # K3s data
└── storage/                 # Persistent volumes (local-path)
    ├── default-*/          # PVC directories
    └── ...
```

## Setup Procedure

### Automated Setup (Recommended)

Use the Ansible playbook to set up NVMe storage:

```bash
cd ansible
ansible-playbook playbooks/setup-nvme-storage.yml \
  -i inventory/hosts.yml \
  --ask-become-pass
```

This playbook will:
1. Partition and format the NVMe SSD
2. Create mount points and filesystem structure
3. Move K3s data directory to NVMe
4. Configure local-path storage to use NVMe
5. Update fstab for automatic mounting
6. Restart K3s to apply changes

### Manual Setup

If you prefer manual setup, follow these steps:

#### 1. Partition and Format NVMe

```bash
# Create partition table
sudo parted /dev/nvme0n1 --script mklabel gpt

# Create single partition using all space
sudo parted /dev/nvme0n1 --script mkpart primary ext4 0% 100%

# Format as ext4
sudo mkfs.ext4 -F /dev/nvme0n1p1

# Label the partition
sudo e2label /dev/nvme0n1p1 nvme-k3s
```

#### 2. Create Mount Points

```bash
sudo mkdir -p /mnt/nvme/{k3s,storage}
```

#### 3. Mount NVMe

```bash
# Mount temporarily
sudo mount /dev/nvme0n1p1 /mnt/nvme

# Create directories
sudo mkdir -p /mnt/nvme/k3s /mnt/nvme/storage
```

#### 4. Move K3s Data Directory

```bash
# Stop K3s
sudo systemctl stop k3s

# Copy K3s data to NVMe
sudo cp -a /var/lib/rancher/k3s/* /mnt/nvme/k3s/

# Backup original
sudo mv /var/lib/rancher/k3s /var/lib/rancher/k3s.backup

# Create symlink
sudo ln -s /mnt/nvme/k3s /var/lib/rancher/k3s

# Start K3s
sudo systemctl start k3s
```

#### 5. Configure Local-Path Storage

```bash
# Update local-path configmap to use NVMe storage
sudo kubectl patch configmap local-path-config -n kube-system \
  --type merge \
  -p '{"data":{"config.json":"{\"nodePathMap\":[{\"node\":\"DEFAULT_PATH_FOR_NON_LISTED_NODES\",\"paths\":[\"/mnt/nvme/storage\"]}]}"}}'

# Note: This is optional since /var/lib/rancher/k3s/storage will work via symlink,
# but pointing directly to /mnt/nvme/storage is cleaner
```

#### 6. Add to fstab

```bash
# Add to /etc/fstab
echo "UUID=$(sudo blkid -s UUID -o value /dev/nvme0n1p1) /mnt/nvme ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab

# Test mount
sudo mount -a
```

## Verification

After setup, verify the configuration:

```bash
# Check NVMe is mounted
df -h | grep nvme

# Check K3s data location
ls -la /var/lib/rancher/k3s
# Should show symlink to /mnt/nvme/k3s

# Check K3s is running
sudo systemctl status k3s

# Check local-path storage location
kubectl get configmap local-path-config -n kube-system -o yaml | grep -A 3 paths

# Check PVCs are using NVMe
kubectl get pvc --all-namespaces
```

## Performance Benefits

### Before (SD Card)
- Container image pulls: ~10-30 MB/s
- Database I/O: Limited by SD card speed
- Container startup: Slower due to I/O bottleneck

### After (NVMe SSD)
- Container image pulls: ~200-500 MB/s (estimated)
- Database I/O: Much faster, especially for PostgreSQL
- Container startup: Faster due to better I/O performance
- SD card wear: Significantly reduced

## Migration Considerations

### Existing PVCs

If you have existing PVCs, you'll need to migrate them:

1. **Backup existing data** (already done via backup scripts)
2. **Delete and recreate PVCs** (data will be lost, restore from backup)
3. **Or manually migrate** (more complex, requires downtime)

### Downtime

The migration requires:
- **K3s downtime**: ~5-10 minutes (to move data directory)
- **Application downtime**: Depends on migration strategy for PVCs

**Recommended approach**: Schedule during maintenance window.

## Maintenance

### Monitoring Storage Usage

```bash
# Check NVMe usage
df -h /mnt/nvme

# Check K3s data size
du -sh /mnt/nvme/k3s/*

# Check PVC storage usage
du -sh /mnt/nvme/storage/*
```

### Cleaning Up

```bash
# Clean unused container images
k3s ctr images prune

# Clean old PVC data (after verifying backups)
# Be careful - this deletes data!
```

## Troubleshooting

### NVMe Not Mounting on Boot

Check fstab entry:
```bash
sudo mount -a
```

If it fails, check UUID:
```bash
sudo blkid /dev/nvme0n1p1
```

### K3s Fails to Start

Check if symlink is correct:
```bash
ls -la /var/lib/rancher/k3s
```

Restore from backup if needed:
```bash
sudo systemctl stop k3s
sudo rm /var/lib/rancher/k3s
sudo mv /var/lib/rancher/k3s.backup /var/lib/rancher/k3s
sudo systemctl start k3s
```

### Local-Path Storage Issues

Check configmap:
```bash
kubectl get configmap local-path-config -n local-path-storage -o yaml
```

Verify directory exists:
```bash
ls -la /mnt/nvme/storage
```

## Long-Term Considerations

1. **Backup Strategy**: Ensure backups include NVMe data (already covered by backup scripts)
2. **Monitoring**: Monitor NVMe health and usage
3. **Expansion**: If you add more nodes, consider NVMe for workers too
4. **RAID**: Not applicable for single-node cluster, but consider for multi-node

## References

- [K3s Data Directory](https://docs.k3s.io/reference/server-config)
- [Local Path Provisioner](https://github.com/rancher/local-path-provisioner)
- [Raspberry Pi NVMe Setup](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html)

