# Setup Node-2 in Eldertree Cluster

This is a complete prompt for setting up a new Raspberry Pi node (node-2) in the eldertree k3s cluster. The Pi is currently booted with an SD card and has the generic hostname "node-x".

## Context

### Current Cluster State

- **node-0**: Control plane node at `192.168.2.86` (gigabit: `10.0.0.1`)
- **node-1**: Worker node at `192.168.2.85` (gigabit: `10.0.0.2`)
- **node-2**: New node to be added (currently booted from SD card with hostname "node-x")

### Node-2 Target Configuration

- **Hostname**: `node-2.eldertree.local` (CRITICAL: Must be FQDN, never just "node-2" or "eldertree")
- **Management IP (wlan0)**: `192.168.2.84` (via NetworkManager/DHCP)
- **Gigabit IP (eth0)**: `10.0.0.3` (static, via NetworkManager, no gateway)
- **Boot Device**: NVMe (SD card will be removed after setup)
- **Role**: k3s worker node

### Current State

- Pi is booted with SD card
- Hostname is "node-x" (generic from Raspberry Pi Imager)
- OS: Debian Bookworm or Trixie (64-bit)
- User: `raolivei` (configured via Raspberry Pi Imager)
- Password: $PI_PASSWORD (user and sudo password for initial setup and Ansible authentication)
- SSH: Enabled (keys configured via Raspberry Pi Imager)

## Prerequisites Check

Before starting, verify:

1. **SSH Access**: Can you SSH to the node?

   ```bash
   # Try to discover the node first
   ping -c 1 node-x.local
   ssh raolivei@node-x.local
   # Password: <PI_PASSWORD> (use environment variable or --ask-pass)
   ```

2. **NVMe Detection**: Is NVMe installed and detected?

   ```bash
   # From your Mac, check if NVMe is visible
   ansible node-x -i ansible/inventory/hosts.yml \
     -m shell -a "lsblk | grep nvme" --become
   ```

3. **Network Connectivity**: Can the node reach the internet and control plane?

   ```bash
   ansible node-x -i ansible/inventory/hosts.yml \
     -m shell -a "ping -c 2 8.8.8.8 && ping -c 2 192.168.2.86" --become
   ```

## Step-by-Step Setup Instructions

### Step 1: Discover Node (if needed)

If you don't know the node's IP address, use the discovery playbook:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook playbooks/discover-nodes.yml
```

This will:

- Try to resolve `node-x.local` via mDNS/DNS
- Display the discovered IP address
- Add the node to a dynamic inventory group `discovered_nodes`

**Expected Output**: Should show the discovered IP, e.g., `🔍 Discovered node-x at IP 192.168.2.XX (via node-x.local)`

### Step 2: Add Node-2 to Inventory

Add node-2 to the Ansible inventory file:

**File**: `ansible/inventory/hosts.yml`

Add this entry under `raspberry_pi.hosts`:

```yaml
node-2:
  ansible_host: 192.168.2.84 # Use discovered IP if different, or set static
  ansible_user: raolivei
  ansible_ssh_private_key_file: ~/.ssh/id_ed25519_raolivei
  ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
  ansible_python_interpreter: /usr/bin/python3
  poe_hat_enabled: true
```

**Note**: If the node is still using DHCP and you don't know the exact IP yet, you can:

- Use the discovered IP from Step 1
- Or use `node-x.local` as `ansible_host` (mDNS will resolve it)
- The management IP will be set to `192.168.2.84` in Step 3

### Step 3: Configure System (Hostname + Management IP)

Run the system setup playbook to configure hostname and management IP:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible

# If using discovered node from Step 1:
ansible-playbook playbooks/setup-system.yml \
  --limit node-x-discovered \
  -e "inventory_hostname=node-2" \
  -e "hostname=node-2.eldertree.local" \
  -e "static_ip=192.168.2.84" \
  --ask-pass --ask-become-pass
# When prompted:
#   SSH password: <PI_PASSWORD> (Raspberry Pi user password)
#   BECOME password (sudo): <PI_PASSWORD> (Raspberry Pi sudo password, NOT your Mac's)

# Or if node-2 is already in inventory:
ansible-playbook playbooks/setup-system.yml \
  --limit node-2 \
  -e "hostname=node-2.eldertree.local" \
  -e "static_ip=192.168.2.84" \
  --ask-pass --ask-become-pass
# When prompted:
#   SSH password: <PI_PASSWORD> (Raspberry Pi user password)
#   BECOME password (sudo): <PI_PASSWORD> (Raspberry Pi sudo password, NOT your Mac's)

# Note: After this playbook runs, passwordless sudo will be configured,
# so subsequent playbooks won't need --ask-become-pass
```

**What this does**:

- Sets hostname to `node-2.eldertree.local` (FQDN)
- Updates `/etc/hostname` and `/etc/hosts`
- Configures NetworkManager for wlan0 (management IP: `192.168.2.84`)
- Installs essential packages (curl, git, bluez, etc.)
- Configures SSH, firewall, cgroups, timezone, NTP
- Configures Bluetooth service

**Verification**:

```bash
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "hostname" --become
# Should show: node-2.eldertree.local

ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "ip addr show wlan0 | grep 'inet '" --become
# Should show: inet 192.168.2.84/24
```

### Step 4: Setup NVMe Boot (if NVMe exists)

If the node has an NVMe drive installed, use the comprehensive NVMe setup playbook:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible

# Setup NVMe boot (partitions, cloning, configuration)
ansible-playbook playbooks/setup-nvme-boot.yml \
  --limit node-2 \
  -e "setup_nvme_boot=true" \
  -e "clone_from_sd=true"
```

**What this does**:

- **Idempotent**: Safe to run multiple times - won't recreate partitions if they already exist and are in use
- Creates GPT partition table (only if partitions don't exist)
- Creates boot partition (1024MiB, FAT32, ESP flag)
- Creates root partition (ext4)
- Formats partitions (only if not already formatted)
- Clones OS from SD card to NVMe (if enabled and root partition is empty)
- Applies comprehensive emergency mode prevention fixes:
  - Clean fstab with correct NVMe PARTUUIDs
  - Clean cmdline.txt with correct root device and cgroup settings
  - Unlocks root account and sets password
  - Disables PAM faillock
  - Removes password expiration

**Important Notes**:

- **Idempotency**: The playbook is safe to run on working nodes. It will:
  - Skip partition creation if partitions exist and are mounted
  - Skip formatting if partitions are already formatted
  - Skip cloning if root partition already has content
  - Only perform necessary operations

- **Force Repartitioning**: If you need to recreate partitions (⚠️ **WARNING: This will erase all data**):
  ```bash
  ansible-playbook playbooks/setup-nvme-boot.yml \
    --limit node-2 \
    -e "setup_nvme_boot=true" \
    -e "force_repartition=true"
  ```

**Verification**:

```bash
# Check if partitions exist
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "lsblk | grep nvme" --become

# Check cmdline.txt (if boot partition is accessible)
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "sudo mount /dev/nvme0n1p1 /mnt/nvme-boot 2>/dev/null && sudo cat /mnt/nvme-boot/cmdline.txt | grep 'root=/dev/nvme0n1p2' && sudo umount /mnt/nvme-boot || echo 'Partition not mounted'" --become
# Should show: root=/dev/nvme0n1p2 in the output
```

**Note**: If no NVMe is detected, skip this step. The node will continue booting from SD card.

### Step 5: Configure Gigabit Network (eth0)

Configure eth0 with the gigabit IP using NetworkManager (NOT netplan):

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet

# Configure eth0 via NetworkManager (matches node-0 pattern)
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "sudo nmcli connection add type ethernet ifname eth0 con-name eth0 ipv4.method manual ipv4.addresses 10.0.0.3/24 ipv4.gateway '' autoconnect yes 2>&1 || sudo nmcli connection modify eth0 ipv4.method manual ipv4.addresses 10.0.0.3/24 ipv4.gateway '' && sudo nmcli connection up eth0" --become

# CRITICAL: Verify persistence
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "sudo ls -la /etc/NetworkManager/system-connections/eth0* && echo '---' && sudo nmcli connection show eth0 | grep -E 'ipv4.method|ipv4.addresses|ipv4.gateway'" --become

# Verify no netplan conflicts
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "sudo grep -r 'eth0' /etc/netplan/ 2>/dev/null || echo 'No netplan files reference eth0'" --become
```

**Expected Output**:

- Connection file should exist: `/etc/NetworkManager/system-connections/eth0`
- `ipv4.method: manual`
- `ipv4.addresses: 10.0.0.3/24`
- `ipv4.gateway: ''` (empty - wlan0 handles default route)
- No netplan files should reference eth0

**Verification**:

```bash
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "ip addr show eth0 | grep 'inet '" --become
# Should show: inet 10.0.0.3/24
```

**⚠️ IMPORTANT**: After configuration, **REBOOT THE NODE** and verify the configuration persists (see Step 9).

### Step 6: Get k3s Token from Control Plane

Get the k3s node token from the control plane (node-0):

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible

# Get token from node-0
K3S_TOKEN=$(ansible node-0 -i inventory/hosts.yml \
  -m shell -a "sudo cat /var/lib/rancher/k3s/server/node-token" \
  --become | grep -v "node-0" | tail -1)

echo "K3S_TOKEN: $K3S_TOKEN"
# Save this token - you'll need it in Step 7
```

**Expected Output**: A long token string (starts with `K10` or similar)

### Step 7: Install k3s Worker

Install k3s worker node using the token from Step 6:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible

# Use the token from Step 6
ansible-playbook playbooks/install-k3s-worker.yml \
  --limit node-2 \
  -e "k3s_token=$K3S_TOKEN" \
  -e "k3s_server_url=https://node-0.eldertree.local:6443"
```

**What this does**:

- Configures cgroup settings (may require reboot)
- Installs k3s-agent
- Connects to control plane at `node-0.eldertree.local:6443`
- Starts k3s-agent service

**Note**: If cgroup configuration is updated, the playbook will automatically reboot the node and wait for it to come back online.

**Verification** (from your Mac):

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
# Should show node-2.eldertree.local (may show as NotReady initially)
```

### Step 8: Configure k3s for Gigabit Network

Configure k3s to use the gigabit network (eth0) instead of wlan0:

**Using Ansible playbook** (recommended):

The `configure-k3s-gigabit.yml` playbook now supports node-2. It will automatically detect node-2 and use the correct gigabit IP (`10.0.0.3`):

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook playbooks/configure-k3s-gigabit.yml --limit node-2
```

**What this does**:

- Verifies eth0 has the gigabit IP configured (`10.0.0.3`)
- Updates k3s-agent service to use `--node-ip=10.0.0.3 --flannel-iface=eth0`
- Reloads systemd and restarts k3s-agent service
- Ensures k3s uses eth0 for cluster traffic instead of wlan0

**Manual Configuration** (if playbook fails or for troubleshooting):

```bash
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "sudo sed -i 's|ExecStart=/usr/local/bin/k3s agent|ExecStart=/usr/local/bin/k3s agent --node-ip=10.0.0.3 --flannel-iface=eth0|' /etc/systemd/system/k3s-agent.service && sudo systemctl daemon-reload && sudo systemctl restart k3s-agent" --become
```

**Verification**:

```bash
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "sudo cat /etc/systemd/system/k3s-agent.service | grep -A 5 'ExecStart='" --become
# Should show: --node-ip=10.0.0.3 --flannel-iface=eth0

# Verify node joined with correct IP
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes -o wide
# Should show node-2.eldertree.local with InternalIP: 10.0.0.3
```

### Step 9: Setup SSH Keys and Terminal Monitoring

Configure SSH keys for node-to-node communication and install terminal monitoring tools:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible

# Setup SSH keys
ansible-playbook playbooks/setup-ssh-keys.yml --limit node-2

# Setup terminal monitoring (btop, neofetch, tmux)
ansible-playbook playbooks/setup-terminal-monitoring.yml \
  --limit node-2 \
  -e "target_user=raolivei"
```

**What this does**:

- Generates SSH key for node-2
- Adds public key to all other nodes (node-0, node-1)
- Installs btop, neofetch, tmux
- Configures login banner with system info

### Step 9.5: Setup Longhorn Prerequisites

Configure Longhorn storage prerequisites on node-2:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible

# Setup Longhorn prerequisites (open-iscsi, /mnt/longhorn mount point)
ansible-playbook playbooks/setup-longhorn-node.yml --limit node-2
```

**What this does**:

- Installs `open-iscsi` package (required for Longhorn)
- Loads iscsi kernel module
- Creates `/mnt/longhorn` directory
- If using dedicated partition, formats and mounts it (optional)

**Optional: Use dedicated partition for Longhorn**:

If you want to use a dedicated partition on the NVMe drive for Longhorn:

```bash
# First, identify available partition (e.g., /dev/nvme0n1p3)
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "lsblk" --become

# Then run playbook with device specified
ansible-playbook playbooks/setup-longhorn-node.yml \
  --limit node-2 \
  -e "longhorn_device=/dev/nvme0n1p3"
```

**Verification**:

```bash
# Check iscsi module
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "lsmod | grep iscsi" --become

# Check mount point
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "ls -la /mnt/longhorn && df -h /mnt/longhorn" --become
```

**Note**: After node-2 joins the cluster, Longhorn will automatically discover it. Verify in Longhorn UI that node-2 appears with disk registered at `/mnt/longhorn`.

### Step 10: Remove SD Card and Reboot

**⚠️ CRITICAL**: After all configuration is complete:

1. **Remove SD card** from the node (physically)

2. **Reboot the node**:

   ```bash
   ansible node-2 -i ansible/inventory/hosts.yml -m reboot --become
   ```

3. **Wait for node to come back online** (30-60 seconds)

4. **Verify boot from NVMe** (if NVMe was configured):

   ```bash
   # Wait for node to come back online
   sleep 30

   # Check root filesystem
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "df -h / | head -2" --become
   # Should show: /dev/nvme0n1p2 (if NVMe boot) or /dev/mmcblk0p2 (if SD card)

   # Check hostname
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "hostname" --become
   # Should show: node-2.eldertree.local

   # Check network
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "ip addr show eth0 | grep 'inet '" --become
   # Should show: inet 10.0.0.3/24

   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "ip addr show wlan0 | grep 'inet '" --become
   # Should show: inet 192.168.2.84/24

   # Verify NetworkManager connection persisted
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "sudo nmcli connection show eth0 | grep -E 'ipv4.method|ipv4.addresses'" --become
   # Should show: ipv4.method: manual, ipv4.addresses: 10.0.0.3/24
   ```

### Step 11: Final Cluster Verification

Verify node-2 is fully integrated into the cluster:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check nodes
kubectl get nodes -o wide

# Expected output:
# NAME                      STATUS   ROLES                       AGE   VERSION   INTERNAL-IP   EXTERNAL-IP
# node-0.eldertree.local    Ready    control-plane,etcd,master   5d    v1.33.5+k3s1   10.0.0.1   <none>
# node-1.eldertree.local    Ready    <none>                      2d    v1.33.5+k3s1   10.0.0.2   <none>
# node-2.eldertree.local    Ready    <none>                      5m    v1.33.5+k3s1   10.0.0.3   <none>

# Check node details
kubectl describe node node-2.eldertree.local

# Verify pods can be scheduled on node-2
kubectl get pods -A -o wide | grep node-2
```

## Reference Information

### Authentication

**User**: `raolivei`  
**User Password**: Set via `PI_PASSWORD` environment variable or `--ask-pass`  
**Sudo Password (on Raspberry Pi)**: Same as user password on fresh installations

**Important Notes**:

- `--ask-become-pass` asks for the **Raspberry Pi's sudo password**, NOT your Mac's sudo password
- You do NOT need your Mac's sudo password for these Ansible operations
- The `setup-system.yml` playbook configures passwordless sudo on the Raspberry Pi, so you'll only need the Pi's sudo password for the initial setup. After the first playbook run, subsequent playbooks won't require it.

**Alternative to --ask-pass**: You can use environment variable instead:

```bash
export env_target_password='<your-password>'
ansible-playbook playbooks/setup-system.yml --limit node-2
```

### IP Assignment Pattern

**Management IPs (wlan0)**:

- node-0: `192.168.2.86`
- node-1: `192.168.2.85`
- node-2: `192.168.2.84`
- Pattern: `192.168.2.8(6-N)` where N is node number

**Gigabit IPs (eth0)**:

- node-0: `10.0.0.1`
- node-1: `10.0.0.2`
- node-2: `10.0.0.3`
- Pattern: `10.0.0.N` where N is node number

### Key File Paths

- Inventory: `ansible/inventory/hosts.yml`
- System setup: `ansible/playbooks/setup-system.yml`
- NVMe boot fix: `ansible/playbooks/fix-nvme-boot.yml`
- k3s worker install: `ansible/playbooks/install-k3s-worker.yml`
- k3s gigabit config: `ansible/playbooks/configure-k3s-gigabit.yml`
- SSH keys: `ansible/playbooks/setup-ssh-keys.yml`
- Terminal monitoring: `ansible/playbooks/setup-terminal-monitoring.yml`
- Longhorn prerequisites: `ansible/playbooks/setup-longhorn-node.yml`
- Master worker setup: `ansible/playbooks/setup-worker-node.yml` (alternative to running individual playbooks)

### Getting k3s Token

```bash
# From node-0 (control plane)
ansible node-0 -i ansible/inventory/hosts.yml \
  -m shell -a "sudo cat /var/lib/rancher/k3s/server/node-token" \
  --become | grep -v "node-0" | tail -1
```

### Verification Commands

```bash
# Hostname
ansible node-2 -i ansible/inventory/hosts.yml -m shell -a "hostname" --become

# Network interfaces
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "ip addr show" --become

# k3s service status
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "sudo systemctl status k3s-agent" --become

# Cluster nodes
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes -o wide

# Node details
kubectl describe node node-2.eldertree.local
```

## Troubleshooting

### Node Boots from SD Card Instead of NVMe

**Symptom**: After removing SD card, node doesn't boot, or `df -h /` shows `/dev/mmcblk0p2`

**Solution**:

1. **Re-run the setup playbook** (idempotent, safe):
   ```bash
   ansible-playbook playbooks/setup-nvme-boot.yml \
     --limit node-2 \
     -e "setup_nvme_boot=true"
   ```
   This will verify and fix boot configuration without recreating partitions.

2. Verify NVMe boot partition has correct `cmdline.txt`:
   ```bash
   # Boot from SD card again
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "sudo mount /dev/nvme0n1p1 /mnt/nvme-boot && sudo cat /mnt/nvme-boot/cmdline.txt | grep 'root=/dev/nvme0n1p2' && sudo umount /mnt/nvme-boot" --become
   ```

3. Ensure SD card is removed before reboot

### Hostname Reverts to node-x

**Symptom**: After reboot, hostname is `node-x` instead of `node-2.eldertree.local`

**Solution**:

1. Verify hostname on NVMe OS (not SD card):

   ```bash
   # While booted from SD card
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "sudo mount /dev/nvme0n1p2 /mnt/nvme-root && sudo cat /mnt/nvme-root/etc/hostname && sudo umount /mnt/nvme-root" --become
   ```

2. Fix if needed:

   ```bash
   ansible-playbook playbooks/setup-system.yml \
     --limit node-2 \
     -e "hostname=node-2.eldertree.local"
   ```

### Network Configuration Doesn't Persist After Reboot

**Symptom**: Network configuration works immediately but is lost after reboot

**Solution**:

1. **Verify connection file exists**:

   ```bash
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "sudo ls -la /etc/NetworkManager/system-connections/eth0*" --become
   ```

2. **Check for netplan conflicts**:

   ```bash
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "sudo grep -r 'eth0' /etc/netplan/" --become
   # Should show no results (or only wlan0 references)
   ```

3. **Match node-0's exact configuration**:

   ```bash
   # On node-0
   ansible node-0 -i ansible/inventory/hosts.yml \
     -m shell -a "sudo cat /etc/NetworkManager/system-connections/eth0" --become
   # Replicate exact same configuration on node-2
   ```

### k3s-agent Can't Connect to Control Plane

**Symptom**: `k3s-agent` service fails with connection errors

**Solution**:

1. Verify gigabit IP is configured:

   ```bash
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "ip addr show eth0 | grep '10.0.0'" --become
   ```

2. Verify k3s-agent service has correct flags:

   ```bash
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "sudo cat /etc/systemd/system/k3s-agent.service | grep -A 5 'ExecStart='" --become
   # Should show: --node-ip=10.0.0.3 --flannel-iface=eth0
   ```

3. Test connectivity to control plane:

   ```bash
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "ping -c 2 10.0.0.1 && ping -c 2 node-0.eldertree.local" --become
   ```

4. Re-run gigabit configuration:

   ```bash
   ansible-playbook playbooks/configure-k3s-gigabit.yml --limit node-2
   ```

### Node Not Showing in Cluster

**Symptom**: `kubectl get nodes` doesn't show node-2

**Solution**:

1. Check k3s-agent service status:

   ```bash
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "sudo systemctl status k3s-agent" --become
   ```

2. Check k3s-agent logs:

   ```bash
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "sudo journalctl -u k3s-agent --no-pager -n 50" --become
   ```

3. Verify token is correct:

   ```bash
   # Get token from node-0 again
   ansible node-0 -i ansible/inventory/hosts.yml \
     -m shell -a "sudo cat /var/lib/rancher/k3s/server/node-token" --become
   ```

4. Re-run k3s worker installation:

   ```bash
   ansible-playbook playbooks/install-k3s-worker.yml \
     --limit node-2 \
     -e "k3s_token=<NEW_TOKEN>" \
     -e "k3s_server_url=https://node-0.eldertree.local:6443"
   ```

## Related Documentation

- [Complete Node Addition Guide](./ADD_NODE_COMPLETE.md) - Detailed step-by-step guide
- [Network Architecture](./NETWORK_ARCHITECTURE.md) - Network design overview
- [Network Configuration Lessons](./NETWORK_CONFIGURATION_LESSONS.md) - Common pitfalls
- [Node IP Assignment](./NODE_IP_ASSIGNMENT.md) - IP address planning
- [Ansible README](../ansible/README.md) - Ansible playbook documentation

## Quick Reference Checklist

When setting up node-2:

- [ ] Step 1: Discover node (if needed)
- [ ] Step 2: Add node-2 to inventory (`ansible/inventory/hosts.yml`)
- [ ] Step 3: Configure system (hostname + management IP)
- [ ] Step 4: Fix NVMe boot configuration (if NVMe exists)
- [ ] Step 5: Configure gigabit network (eth0)
- [ ] Step 6: Get k3s token from node-0
- [ ] Step 7: Install k3s worker
- [ ] Step 8: Configure k3s for gigabit network
- [ ] Step 9: Setup SSH keys and terminal monitoring
- [ ] Step 9.5: Setup Longhorn prerequisites
- [ ] Step 10: Remove SD card and reboot
- [ ] Step 11: Final cluster verification

## Notes

- **CRITICAL**: All hostnames must be FQDN: `node-2.eldertree.local` (never just "node-2" or "eldertree")
- **NetworkManager**: Both wlan0 and eth0 are managed by NetworkManager (not netplan for eth0)
- **Boot Order**: SD card takes precedence over NVMe - remove SD card before final reboot
- **IP Persistence**: Always verify network configuration persists after reboot
- **k3s Token**: Token is required for worker node join - get it from node-0
- **Gigabit Network**: k3s uses eth0 (10.0.0.x) for cluster traffic, wlan0 (192.168.2.x) for management
