# Node Reinstallation Checklist

## Overview

This checklist covers what needs to be reconfigured when a node is reinstalled with a fresh OS.

## Quick Setup for node-1

### Prerequisites

- Fresh OS installed on SD card
- Node is booting up
- SSH access with default credentials (or password from inventory)
- ✅ `PI_PASSWORD` environment variable set: `export PI_PASSWORD='your_password'`

### Step 1: Verify Basic Connectivity

```bash
# Remove old SSH host key (if needed)
ssh-keygen -R node-1.local
ssh-keygen -R 192.168.2.85

# Test connectivity using PI_PASSWORD
sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no raolivei@node-1.local "hostname"
```

### Step 2: Run System Setup

```bash
cd pi-fleet/ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/setup-system.yml \
  --limit node-1 \
  -e "node_hostname=node-1" \
  -e "node_ip=" \
  --ask-pass
```

**Note:** Leave `node_ip` empty to use DHCP (safer).

### Step 3: Verify NVMe Backup Partition

The backup partition on NVMe should still exist from previous setup:

```bash
# Check if partition exists
ssh raolivei@node-1.local "sudo lsblk | grep nvme"

# Mount backup partition if needed
ssh raolivei@node-1.local "sudo mkdir -p /mnt/backup-nvme && sudo mount /dev/nvme0n1p3 /mnt/backup-nvme && df -h /mnt/backup-nvme"
```

### Step 4: Configure eth0 (Router DHCP Reservation)

**Recommended approach** - Use router DHCP reservations instead of static IP:

1. Get eth0 MAC address:

   ```bash
   ssh raolivei@node-1.local "ip link show eth0 | grep ether"
   ```

2. Configure router:

   - Login to router admin (192.168.2.1)
   - Add DHCP reservation: MAC → 192.168.2.85 (or appropriate IP for the node)

3. Verify:
   ```bash
   ssh raolivei@node-1.local "ip addr show eth0"
   ```

### Step 5: Install k3s Worker (if needed)

```bash
cd pi-fleet/ansible

# Get k3s token from node-1
K3S_TOKEN=$(ssh raolivei@192.168.2.86 "sudo cat /var/lib/rancher/k3s/server/node-token")

# Install k3s worker
ansible-playbook -i inventory/hosts.yml \
  playbooks/install-k3s-worker.yml \
  --limit node-1 \
  -e "k3s_token=$K3S_TOKEN" \
  -e "k3s_node_name=node-1"
```

### Step 6: Setup Terminal Monitoring (optional)

```bash
cd pi-fleet/ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/setup-terminal-monitoring.yml \
  --limit node-1
```

## What Persists After Reinstall

✅ **NVMe partitions** - Backup partition (p3) should still exist
✅ **NVMe data** - Any data on NVMe partitions persists
✅ **Network configuration** - Router DHCP reservations persist

## What Needs Reconfiguration

❌ **OS configuration** - User, hostname, packages
❌ **SSH keys** - Host keys change with fresh OS
❌ **k3s installation** - Needs to be reinstalled
❌ **Mount points** - Need to be recreated/mounted
❌ **System services** - Need to be reconfigured

## Complete Setup Script

For a complete automated setup:

```bash
cd pi-fleet/ansible

# Full system setup
ansible-playbook -i inventory/hosts.yml \
  playbooks/setup-worker-node.yml \
  --limit node-1 \
  -e "hostname_var=node-1" \
  -e "static_ip_var=" \
  --ask-pass

# Then get k3s token and install worker
K3S_TOKEN=$(ssh raolivei@192.168.2.86 "sudo cat /var/lib/rancher/k3s/server/node-token")

ansible-playbook -i inventory/hosts.yml \
  playbooks/install-k3s-worker.yml \
  --limit node-1 \
  -e "k3s_token=$K3S_TOKEN" \
  -e "k3s_node_name=node-1"
```

## Verification Checklist

After setup, verify:

- [ ] SSH access works
- [ ] Hostname is correct: `node-1`
- [ ] User `raolivei` exists
- [ ] NVMe backup partition is mounted at `/mnt/backup-nvme`
- [ ] eth0 configured (if using isolated switch: 10.0.0.X/24, or via DHCP if connected to router)
- [ ] Internet connectivity works
- [ ] k3s worker joined cluster (if applicable)
- [ ] Can ping node-1 from node-1

## Troubleshooting

### SSH Host Key Changed

```bash
ssh-keygen -R node-1.local
ssh-keygen -R 192.168.2.85
```

### Backup Partition Not Mounted

```bash
# Check partition exists
sudo lsblk | grep nvme

# Mount manually
sudo mkdir -p /mnt/backup-nvme
sudo mount /dev/nvme0n1p3 /mnt/backup-nvme

# Add to fstab for persistence
echo '/dev/nvme0n1p3 /mnt/backup-nvme ext4 defaults 0 2' | sudo tee -a /etc/fstab
```

### k3s Worker Not Joining

1. Check token is correct
2. Check node-1 is accessible
3. Check firewall rules
4. Check k3s logs: `sudo journalctl -u k3s-agent -f`
