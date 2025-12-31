# Complete Guide: Adding a New Node to Eldertree Cluster

This guide covers the complete process for adding a new Raspberry Pi node to the eldertree cluster, including NVMe boot configuration, network setup, and k3s integration.

> **💡 Quick Setup Option**: For a streamlined setup, you can use the master playbook `setup-new-node.yml` which automates all steps below. See [Ansible Playbook Analysis](../ansible/PLAYBOOK_ANALYSIS.md) for usage examples.

## Overview

When adding a new node to the eldertree cluster, follow this pattern (established with node-0 and node-1):

- **Management IP**: On `wlan0` via NetworkManager/DHCP (e.g., `192.168.2.85`)
- **Gigabit IP**: On `eth0` via NetworkManager (e.g., `10.0.0.2`)
- **Boot**: From NVMe drive (SD card removed after setup)
- **Hostname**: `node-X.eldertree.local` (where X is the node number)

## Prerequisites

- Raspberry Pi 5 with NVMe drive installed
- SD card with OS installed (used temporarily during setup)
- Physical access to the node
- Ansible access from your Mac

## Step-by-Step Process

### Step 1: Initial OS Installation (SD Card)

1. **Flash OS to SD card** using Raspberry Pi Imager:
   - OS: Debian Bookworm or Trixie (64-bit)
   - Enable SSH
   - Set username: `raolivei`
   - Set password (remember it for initial setup)

2. **Boot the Pi with SD card**:
   - Insert SD card
   - Connect power and Ethernet
   - Wait for boot (30-60 seconds)
   - Note the IP address assigned via DHCP

3. **Clone OS to NVMe**:
   - Use existing scripts or manual process to clone SD card OS to NVMe
   - This creates boot and root partitions on NVMe

### Step 2: Fix NVMe Boot Configuration

The NVMe boot partition needs correct `cmdline.txt` to boot from NVMe root partition.

**Using Ansible playbook** (recommended):

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook playbooks/fix-nvme-boot.yml --limit node-X
```

**What it does**:
- Mounts NVMe boot partition (`/dev/nvme0n1p1`)
- Updates `cmdline.txt` to point to `/dev/nvme0n1p2`
- Adds cgroup parameters for k3s
- Ensures proper boot configuration

**Manual verification** (if needed):

```bash
# On the node (while booted from SD card)
sudo mount /dev/nvme0n1p1 /mnt/nvme-boot
sudo cat /mnt/nvme-boot/cmdline.txt
# Should contain: root=/dev/nvme0n1p2 rootfstype=ext4 rootwait rootdelay=5
sudo umount /mnt/nvme-boot
```

### Step 3: Configure System (Hostname + Management IP)

**Using Ansible playbook**:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook playbooks/setup-system.yml \
  --limit node-X \
  -e "hostname=node-X.eldertree.local" \
  -e "static_ip=192.168.2.XX"
```

**What it does**:
- Sets hostname to `node-X.eldertree.local`
- Updates `/etc/hostname` and `/etc/hosts`
- Configures NetworkManager for wlan0 (management IP)
- Installs essential packages
- Configures SSH, firewall, etc.

**Important**: The `static_ip` parameter is for wlan0 management IP. NetworkManager will handle this via DHCP, but the playbook ensures proper configuration.

### Step 4: Configure Network (Gigabit IP on eth0)

**Pattern**: Match node-0's configuration - eth0 gets gigabit IP via NetworkManager, wlan0 handles management.

**Using Ansible** (on running node):

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet

# Configure eth0 via NetworkManager (matches node-0 pattern)
ansible node-X -i ansible/inventory/hosts.yml \
  -m shell -a "sudo nmcli connection add type ethernet ifname eth0 con-name eth0 ipv4.method manual ipv4.addresses 10.0.0.X/24 ipv4.gateway '' autoconnect yes 2>&1 || sudo nmcli connection modify eth0 ipv4.method manual ipv4.addresses 10.0.0.X/24 ipv4.gateway '' && sudo nmcli connection up eth0" --become

# CRITICAL: Verify persistence
ansible node-X -i ansible/inventory/hosts.yml \
  -m shell -a "sudo ls -la /etc/NetworkManager/system-connections/eth0* && echo '---' && sudo nmcli connection show eth0 | grep -E 'ipv4.method|ipv4.addresses|ipv4.gateway'" --become

# Verify no netplan conflicts
ansible node-X -i ansible/inventory/hosts.yml \
  -m shell -a "sudo grep -r 'eth0' /etc/netplan/ 2>/dev/null || echo 'No netplan files reference eth0'" --become
```

**⚠️ IMPORTANT**: After configuration, **REBOOT THE NODE** and verify the configuration persists. See [Network Configuration Lessons](NETWORK_CONFIGURATION_LESSONS.md) for common pitfalls.

**Network Configuration Pattern**:

- **wlan0**: Managed by NetworkManager (via `90-NM-*.yaml` netplan file)
  - Gets management IP via DHCP (e.g., `192.168.2.85`)
  - Handles default route
  - Handles DNS

- **eth0**: Managed by NetworkManager (via `nmcli` connection)
  - Static gigabit IP only (e.g., `10.0.0.2`)
  - No gateway (wlan0 handles default route)
  - No DNS (wlan0 handles DNS)
  - Connection name: `eth0`

**Why this pattern?**:
- Both interfaces managed by NetworkManager (consistent)
- Matches node-0's working configuration exactly
- No netplan files needed for eth0
- Keeps management and cluster networking separate

### Step 5: Add Node as k3s Worker

**Using Ansible playbook**:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible

# Get k3s token from control plane
K3S_TOKEN=$(ansible node-0 -i inventory/hosts.yml -m shell -a "sudo cat /var/lib/rancher/k3s/server/node-token" --become | grep -v "node-0" | tail -1)

# Install k3s worker
ansible-playbook playbooks/install-k3s-worker.yml \
  --limit node-X \
  -e "k3s_token=$K3S_TOKEN" \
  -e "k3s_server_url=https://node-0.eldertree.local:6443"
```

**What it does**:
- Installs k3s-agent
- Configures cgroup settings
- Starts k3s-agent service
- Connects to control plane

### Step 6: Configure k3s to Use Gigabit Network

**Using Ansible playbook**:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook playbooks/configure-k3s-gigabit.yml --limit node-X
```

**What it does**:
- Updates `k3s-agent.service` to include:
  - `--node-ip=10.0.0.X` (gigabit IP)
  - `--flannel-iface=eth0` (gigabit interface)
- Reloads systemd and restarts k3s-agent
- Verifies node joined cluster with correct IP

**Manual verification** (if needed):

```bash
# Check service file
ansible node-X -i ansible/inventory/hosts.yml \
  -m shell -a "sudo cat /etc/systemd/system/k3s-agent.service | grep -A 5 'ExecStart='" --become

# Should show:
# ExecStart=/usr/local/bin/k3s \
#     agent \
#     --node-ip=10.0.0.X \
#     --flannel-iface=eth0 \
```

### Step 7: Remove SD Card and Reboot

**Important**: After all configuration is complete on NVMe OS:

1. **Remove SD card** from the node
2. **Reboot** the node:
   ```bash
   ansible node-X -i ansible/inventory/hosts.yml -m reboot --become
   ```

3. **Wait for node to come back online** (30-60 seconds)

4. **Verify boot from NVMe**:
   ```bash
   # Wait for node to come back online
   sleep 30
   
   # Check root filesystem
   ansible node-X -i ansible/inventory/hosts.yml \
     -m shell -a "df -h / | head -2" --become
   # Should show: /dev/nvme0n1p2
   
   # Check hostname
   ansible node-X -i ansible/inventory/hosts.yml \
     -m shell -a "hostname" --become
   # Should show: node-X.eldertree.local
   
   # Check network
   ansible node-X -i ansible/inventory/hosts.yml \
     -m shell -a "ip addr show eth0 | grep 'inet '" --become
   # Should show: inet 10.0.0.X/24
   
   ansible node-X -i ansible/inventory/hosts.yml \
     -m shell -a "ip addr show wlan0 | grep 'inet '" --become
   # Should show: inet 192.168.2.XX/24
   
   # Verify NetworkManager connection persisted
   ansible node-X -i ansible/inventory/hosts.yml \
     -m shell -a "sudo nmcli connection show eth0 | grep -E 'ipv4.method|ipv4.addresses'" --become
   # Should show: ipv4.method: manual, ipv4.addresses: 10.0.0.X/24
   ```

**⚠️ CRITICAL**: If configuration doesn't persist after reboot, see [Network Configuration Lessons](NETWORK_CONFIGURATION_LESSONS.md) for troubleshooting.

### Step 8: Verify Cluster Integration

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes -o wide
```

Should show:
```
NAME                      STATUS   ROLES                       AGE   VERSION   INTERNAL-IP   EXTERNAL-IP
node-0.eldertree.local    Ready    control-plane,etcd,master   5d    v1.33.5+k3s1   10.0.0.1   <none>
node-X.eldertree.local    Ready    <none>                      5m    v1.33.5+k3s1   10.0.0.X   <none>
```

## IP Address Assignment

### Management IPs (wlan0)
- **node-0**: `192.168.2.86`
- **node-1**: `192.168.2.85`
- **node-2**: `192.168.2.84` (example)
- **node-3**: `192.168.2.83` (example)

### Gigabit IPs (eth0)
- **node-0**: `10.0.0.1`
- **node-1**: `10.0.0.2`
- **node-2**: `10.0.0.3` (example)
- **node-3**: `10.0.0.4` (example)

## Troubleshooting

### Node Boots from SD Card Instead of NVMe

**Symptom**: After removing SD card, node doesn't boot, or `df -h /` shows `/dev/mmcblk0p2`

**Solution**:
1. Verify NVMe boot partition has correct `cmdline.txt`:
   ```bash
   # Boot from SD card
   sudo mount /dev/nvme0n1p1 /mnt/nvme-boot
   sudo cat /mnt/nvme-boot/cmdline.txt | grep "root=/dev/nvme0n1p2"
   ```

2. Re-run NVMe boot fix playbook:
   ```bash
   ansible-playbook playbooks/fix-nvme-boot.yml --limit node-X
   ```

3. Ensure SD card is removed before reboot

### Hostname Reverts to node-x

**Symptom**: After reboot, hostname is `node-x` instead of `node-X.eldertree.local`

**Solution**:
1. Verify hostname on NVMe OS (not SD card):
   ```bash
   # While booted from SD card
   sudo mount /dev/nvme0n1p2 /mnt/nvme-root
   sudo cat /mnt/nvme-root/etc/hostname
   sudo grep "127.0.1.1" /mnt/nvme-root/etc/hosts
   ```

2. Fix if needed:
   ```bash
   ansible-playbook playbooks/setup-system.yml \
     --limit node-X \
     -e "hostname=node-X.eldertree.local"
   ```

### Network Connectivity Issues

**Symptom**: IPs assigned but can't ping gateway or external

**Solution**:
1. Check NetworkManager configuration:
   ```bash
   sudo nmcli connection show eth0
   # Should show: ipv4.method: manual, ipv4.addresses: 10.0.0.X/24
   ```

2. Verify NetworkManager is managing both interfaces:
   ```bash
   sudo systemctl status NetworkManager
   sudo nmcli device status
   # Both wlan0 and eth0 should show as managed
   ```

3. Check routing:
   ```bash
   ip route show
   # Default route should be via wlan0
   ```

4. Ensure eth0 NetworkManager connection has no gateway:
   ```bash
   sudo nmcli connection modify eth0 ipv4.gateway ''
   sudo nmcli connection up eth0
   ```

### Network Configuration Doesn't Persist After Reboot

**Symptom**: Network configuration works immediately but is lost after reboot

**Solution**:
1. **Verify connection file exists**:
   ```bash
   sudo ls -la /etc/NetworkManager/system-connections/eth0*
   # Should show connection file
   ```

2. **Check for netplan conflicts**:
   ```bash
   sudo grep -r "eth0" /etc/netplan/
   # Should show no results (or only wlan0 references)
   ```

3. **Verify NetworkManager keyfile plugin**:
   ```bash
   sudo cat /etc/NetworkManager/NetworkManager.conf | grep -i keyfile
   # Check if keyfile plugin is reading netplan files
   ```

4. **Match node-0's exact configuration**:
   ```bash
   # On node-0
   sudo ls -la /etc/NetworkManager/system-connections/eth0*
   sudo cat /etc/NetworkManager/system-connections/eth0
   # Replicate exact same configuration on new node
   ```

**See**: [Network Configuration Lessons](NETWORK_CONFIGURATION_LESSONS.md) for detailed troubleshooting and common pitfalls.

### k3s-agent Can't Connect to Control Plane

**Symptom**: `k3s-agent` service fails with connection errors

**Solution**:
1. Verify gigabit IP is configured:
   ```bash
   ip addr show eth0 | grep "10.0.0"
   ```

2. Verify k3s-agent service has correct flags:
   ```bash
   sudo cat /etc/systemd/system/k3s-agent.service | grep -A 5 "ExecStart="
   # Should show: --node-ip=10.0.0.X --flannel-iface=eth0
   ```

3. Test connectivity to control plane:
   ```bash
   ping -c 2 10.0.0.1  # Control plane gigabit IP
   ping -c 2 node-0.eldertree.local
   ```

4. Re-run gigabit configuration:
   ```bash
   ansible-playbook playbooks/configure-k3s-gigabit.yml --limit node-X
   ```

## Quick Reference Checklist

When adding a new node:

- [ ] OS installed on SD card and cloned to NVMe
- [ ] NVMe boot configuration fixed (`fix-nvme-boot.yml`)
- [ ] System configured (hostname + management IP) (`setup-system.yml`)
- [ ] Network configured (eth0 gigabit IP only) (`10-eth0-gigabit.yaml`)
- [ ] k3s worker installed (`install-k3s-worker.yml`)
- [ ] k3s configured for gigabit network (`configure-k3s-gigabit.yml`)
- [ ] SD card removed
- [ ] Node rebooted
- [ ] Verified boot from NVMe (`df -h /` shows `/dev/nvme0n1p2`)
- [ ] Verified hostname (`hostname` shows `node-X.eldertree.local`)
- [ ] Verified network (both IPs assigned, connectivity works)
- [ ] Verified cluster integration (`kubectl get nodes`)

## Related Documentation

- [Network Architecture](NETWORK_ARCHITECTURE.md) - Overview of network design
- [Network Configuration Lessons](NETWORK_CONFIGURATION_LESSONS.md) - **CRITICAL**: Common pitfalls and persistence issues
- [NVMe Boot Setup](NVME_BOOT_SETUP.md) - Detailed NVMe boot configuration
- [Node IP Assignment](NODE_IP_ASSIGNMENT.md) - IP address planning
- [k3s Service Troubleshooting](K3S_SERVICE_TROUBLESHOOTING.md) - k3s-specific issues

