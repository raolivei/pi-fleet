# Fresh Install Guide for node-0 (eldertree)

## Overview

This guide covers setting up node-0 (eldertree) from a fresh OS installation. This is the recommended approach when:
- System is stuck in emergency mode
- Root account is locked
- fstab has problematic mount entries
- You want a clean slate

## Prerequisites

- ✅ Fresh OS installed on SD card (Debian Bookworm/Trixie)
- ✅ SD card inserted in node-0
- ✅ Node-0 powered on and booted
- ✅ SSH access available (default password or configured)

## Step 1: Flash OS to SD Card

Use Raspberry Pi Imager:

1. **Open Raspberry Pi Imager**
2. **Choose OS**: Debian Bookworm (64-bit) or Debian Trixie (64-bit)
3. **Choose Storage**: Your SD card
4. **Configure** (gear icon):
   - ✅ Enable SSH
   - Username: `raolivei` (or `pi` if using default)
   - Password: `Control01!`
   - Configure WiFi (optional, or use Ethernet)
5. **Write** to SD card
6. **Insert SD card** into node-0
7. **Power on** node-0

## Step 2: Find IP Address

```bash
# Check router admin panel, or scan network:
nmap -sn 192.168.2.0/24 | grep -B 2 "Raspberry Pi"
```

Or check router DHCP leases for the new device.

## Step 3: SSH and Verify

```bash
# Remove old SSH host key (if exists)
ssh-keygen -R node-0.local
ssh-keygen -R 192.168.2.86

# SSH to node-0
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@192.168.2.86
# Or if using default user:
sshpass -p 'raspberry' ssh -o StrictHostKeyChecking=no pi@192.168.2.86
```

## Step 4: Run Complete System Setup

From your Mac:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible

# Run complete system setup (DHCP - safe, network unchanged)
ansible-playbook -i inventory/hosts.yml \
  playbooks/setup-system.yml \
  --limit node-0 \
  -e "node_hostname=node-0" \
  -e "backup_device=" \
  --ask-pass

# Note: This keeps DHCP enabled (safer). To configure static IP, add:
# -e "configure_static_ip=true" -e "static_ip=192.168.2.86"
```

**Note**: Leave `backup_device` empty for now (we'll configure it later if needed).

This playbook will:
- ✅ Create `raolivei` user (if not exists)
- ✅ Set hostname to `node-0`
- ✅ Configure network (static IP: 192.168.2.86)
- ✅ Install essential packages (btop, sshpass, etc.)
- ✅ Configure SSH
- ✅ **Unlock root account** (prevents lock issues)
- ✅ Configure system settings

## Step 5: Setup SSH Keys

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible

# Setup SSH keys for node-to-node communication
ansible-playbook -i inventory/hosts.yml \
  playbooks/setup-ssh-keys.yml \
  --limit node-0
```

## Step 6: Configure eth0 (Isolated Switch)

If you have the gigabit switch connected:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible

# Configure eth0 with isolated subnet (10.0.0.1/24)
ansible-playbook -i inventory/hosts.yml \
  playbooks/configure-eth0-static.yml \
  --limit node-0 \
  -e "eth0_ip=10.0.0.1"
```

## Step 7: Install K3s (Control Plane)

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible

# Install K3s as control plane
ansible-playbook -i inventory/hosts.yml \
  playbooks/install-k3s-server.yml \
  --limit node-0
```

## Step 8: Setup Terminal Monitoring (Optional)

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible

# Install btop, neofetch, tmux
ansible-playbook -i inventory/hosts.yml \
  playbooks/setup-terminal-monitoring.yml \
  --limit node-0
```

## Step 9: Verify Setup

```bash
# SSH to node-0
ssh raolivei@192.168.2.86

# Check hostname
hostname
# Should show: node-0

# Check IP
ip addr show
# Should show: 192.168.2.86

# Check root account
sudo passwd -S root
# Should show: P (password set, not locked)

# Check K3s
sudo kubectl get nodes
# Should show: node-0

# Check btop
which btop
# Should show: /usr/bin/btop
```

## Step 10: Configure NVMe Boot (Later)

Once the system is stable, you can configure NVMe boot:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible

# Backup data first (if needed)
# Then setup NVMe boot with storage partition
ansible-playbook -i inventory/hosts.yml \
  playbooks/setup-nvme-boot.yml \
  --limit node-0 \
  -e setup_nvme_boot=true \
  -e clone_from_sd=true \
  -e create_storage_partition=true \
  -e root_partition_size=30GiB
```

**Note**: The playbook will automatically unlock root after boot configuration to prevent lock issues.

## Quick Reference

### Complete Setup (All Steps)

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible

# 1. System setup
ansible-playbook -i inventory/hosts.yml playbooks/setup-system.yml \
  --limit node-0 -e "node_hostname=node-0" -e "node_ip=192.168.2.86" \
  -e "backup_device=" --ask-pass

# 2. SSH keys
ansible-playbook -i inventory/hosts.yml playbooks/setup-ssh-keys.yml \
  --limit node-0

# 3. eth0 (if using isolated switch)
ansible-playbook -i inventory/hosts.yml playbooks/configure-eth0-static.yml \
  --limit node-0 -e "eth0_ip=10.0.0.1"

# 4. K3s server
ansible-playbook -i inventory/hosts.yml playbooks/install-k3s-server.yml \
  --limit node-0

# 5. Terminal monitoring
ansible-playbook -i inventory/hosts.yml playbooks/setup-terminal-monitoring.yml \
  --limit node-0
```

## Troubleshooting

### SSH Connection Issues

```bash
# Remove old host keys
ssh-keygen -R node-0.local
ssh-keygen -R 192.168.2.86

# Try with password
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@192.168.2.86
```

### Root Account Locked

The `setup-system.yml` playbook should prevent this, but if it happens:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook -i inventory/hosts.yml playbooks/fix-root-lock.yml --limit node-0
```

### Network Issues

If node-0 doesn't get the expected IP:

```bash
# Check current IP
ssh raolivei@node-0.local "ip addr show"

# Re-run network setup
ansible-playbook -i inventory/hosts.yml playbooks/setup-system.yml \
  --limit node-0 -e "node_hostname=node-0" -e "node_ip=192.168.2.86"
```

## Next Steps

After fresh install:
1. ✅ Verify all services are running
2. ✅ Test node-to-node communication (node-0 ↔ node-1)
3. ✅ Configure NVMe boot (when ready)
4. ✅ Restore K3s workloads (if needed)

## Related Documentation

- [ADD_WORKER_NODE.md](./ADD_WORKER_NODE.md) - Adding worker nodes
- [NODE_REINSTALLATION_CHECKLIST.md](./NODE_REINSTALLATION_CHECKLIST.md) - Reinstallation checklist
- [EMERGENCY_MODE_RECOVERY.md](./EMERGENCY_MODE_RECOVERY.md) - Emergency mode recovery (if issues occur)

