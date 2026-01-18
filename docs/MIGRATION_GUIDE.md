# Node Migration Guide: Rename and IP Update

This guide walks you through migrating nodes from old names/IPs to new ones.

## Migration Overview

**Old → New:**

- `node-1` → `node-1` (192.168.2.86 → 192.168.2.101)
- `node-1` → `node-2` (192.168.2.85 → 192.168.2.102)
- `node-2` → `node-3` (192.168.2.84 → 192.168.2.103)

**Note:** eth0 IPs (10.0.0.1, 10.0.0.2, 10.0.0.3) do NOT change - they're based on physical position.

## Prerequisites

1. ✅ **All nodes accessible via old IPs** (verify with `ping`)
2. ✅ **Router DHCP reservations updated** for new IPs (192.168.2.101, 102, 103)
3. ✅ **Ansible inventory updated** (`ansible/inventory/hosts.yml` has new names/IPs)
4. ✅ **Backup current state** (optional but recommended)

## Step-by-Step Migration

### Step 1: Verify Current State

```bash
# Verify nodes are accessible with old IPs
ping -c 2 192.168.2.86  # node-1 (old)
ping -c 2 192.168.2.85  # node-1 (old)
ping -c 2 192.168.2.84  # node-2 (old)

# Verify cluster is working
kubectl --kubeconfig ~/.kube/config-eldertree get nodes
```

### Step 2: Update Router DHCP Reservations

**IMPORTANT:** Do this BEFORE running the migration playbook!

1. Access router admin panel (usually `192.168.2.1`)
2. Navigate to **DHCP Reservations** or **Static IP Assignments**
3. Update reservations:
   - MAC of old `node-1` → `192.168.2.101` (new `node-1`)
   - MAC of old `node-1` → `192.168.2.102` (new `node-2`)
   - MAC of old `node-2` → `192.168.2.103` (new `node-3`)
4. Save and apply changes

### Step 3: Run Migration Playbook

The playbook uses a temporary inventory with old IPs to connect to nodes:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet

# Run migration playbook with temporary inventory (old IPs)
ansible-playbook \
  -i ansible/inventory/hosts-migration-temp.yml \
  ansible/playbooks/migrate-node-names-and-ips.yml
```

**What the playbook does:**

- Updates `/etc/hosts` on all nodes
- Updates hostname to new name
- Updates NetworkManager wlan0 IP to new IP
- Updates NetworkManager eth0 IP (ensures correct)
- Updates k3s service configuration (control plane)
- Updates k3s-agent service configuration (workers)
- Reloads systemd

### Step 4: Reboot Nodes (One at a Time)

**IMPORTANT:** Reboot nodes one at a time, starting with the control plane!

#### 4.1: Reboot Control Plane (node-1 → node-1)

```bash
# Reboot control plane
ansible-playbook \
  -i ansible/inventory/hosts-migration-temp.yml \
  ansible/playbooks/migrate-node-names-and-ips.yml \
  --limit node-1 \
  -e "reboot=true"

# Or manually:
ssh raolivei@192.168.2.86 "sudo reboot"

# Wait for node to come back up (2-3 minutes)
# Then verify with new IP
ping -c 2 192.168.2.101
ssh raolivei@192.168.2.101 "hostname"  # Should show: node-1.eldertree.local
```

#### 4.2: Update SSH known_hosts

```bash
# Remove old host keys
ssh-keygen -R 192.168.2.86
ssh-keygen -R node-1.eldertree.local
ssh-keygen -R node-1

# Test SSH with new IP
ssh raolivei@192.168.2.101
```

#### 4.3: Update Kubeconfig

```bash
# Update kubeconfig to use new IP
kubectl config set-cluster default \
  --kubeconfig ~/.kube/config-eldertree \
  --server=https://192.168.2.101:6443

# Or update to use FQDN (better)
kubectl config set-cluster default \
  --kubeconfig ~/.kube/config-eldertree \
  --server=https://node-1.eldertree.local:6443

# Verify cluster access
kubectl --kubeconfig ~/.kube/config-eldertree get nodes
```

#### 4.4: Reboot Worker Nodes (node-1 → node-2, then node-2 → node-3)

```bash
# Reboot node-1 (old) → node-2 (new)
ssh raolivei@192.168.2.85 "sudo reboot"

# Wait for node to come back up, then verify
ping -c 2 192.168.2.102
ssh raolivei@192.168.2.102 "hostname"  # Should show: node-2.eldertree.local

# Update SSH known_hosts
ssh-keygen -R 192.168.2.85
ssh-keygen -R node-1.eldertree.local
ssh-keygen -R node-1

# Reboot node-2 (old) → node-3 (new)
ssh raolivei@192.168.2.84 "sudo reboot"

# Wait for node to come back up, then verify
ping -c 2 192.168.2.103
ssh raolivei@192.168.2.103 "hostname"  # Should show: node-3.eldertree.local

# Update SSH known_hosts
ssh-keygen -R 192.168.2.84
ssh-keygen -R node-2.eldertree.local
ssh-keygen -R node-2
```

### Step 5: Verify Migration

```bash
# Verify all nodes are accessible with new IPs
ping -c 2 192.168.2.101  # node-1
ping -c 2 192.168.2.102  # node-2
ping -c 2 192.168.2.103  # node-3

# Verify hostnames
ssh raolivei@192.168.2.101 "hostname"  # node-1.eldertree.local
ssh raolivei@192.168.2.102 "hostname"  # node-2.eldertree.local
ssh raolivei@192.168.2.103 "hostname"  # node-3.eldertree.local

# Verify cluster
kubectl --kubeconfig ~/.kube/config-eldertree get nodes -o wide

# Should show:
# NAME                    STATUS   ROLES                  AGE   VERSION   INTERNAL-IP   EXTERNAL-IP
# node-1.eldertree.local  Ready    control-plane,master   5d    v1.33.5   10.0.0.1      <none>
# node-2.eldertree.local  Ready    <none>                 5d    v1.33.5   10.0.0.2      <none>
# node-3.eldertree.local  Ready    <none>                 5d    v1.33.5   10.0.0.3      <none>

# Verify Ansible can access nodes with new inventory
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
ansible -i ansible/inventory/hosts.yml raspberry_pi -m ping
```

### Step 6: Cleanup

```bash
# Remove temporary migration inventory (optional)
rm ansible/inventory/hosts-migration-temp.yml

# Update any scripts or documentation that reference old IPs (if needed)
```

## Troubleshooting

### Node doesn't come back up with new IP

1. Check router DHCP reservations
2. Check NetworkManager status: `ssh raolivei@<old-ip> "nmcli connection show"`
3. Manually configure IP if needed: `ssh raolivei@<old-ip> "sudo nmcli connection modify wlan0 ipv4.addresses <new-ip>/24"`

### k3s not starting after migration

1. Check k3s service: `ssh raolivei@<new-ip> "sudo systemctl status k3s"`
2. Check k3s logs: `ssh raolivei@<new-ip> "sudo journalctl -u k3s -n 50"`
3. Verify k3s service file: `ssh raolivei@<new-ip> "sudo cat /etc/systemd/system/k3s.service"`

### Workers not joining cluster

1. Check k3s-agent service: `ssh raolivei@<new-ip> "sudo systemctl status k3s-agent"`
2. Check k3s-agent logs: `ssh raolivei@<new-ip> "sudo journalctl -u k3s-agent -n 50"`
3. Verify control plane is accessible: `ssh raolivei@<new-ip> "ping -c 2 node-1.eldertree.local"`

## Rollback (If Needed)

If migration fails, you can rollback by:

1. Reverting router DHCP reservations to old IPs
2. Reverting hostname: `ssh raolivei@<new-ip> "sudo hostnamectl set-hostname <old-hostname>"`
3. Reverting NetworkManager IP: `ssh raolivei@<new-ip> "sudo nmcli connection modify wlan0 ipv4.addresses <old-ip>/24"`
4. Reverting k3s service files (restore from backup created by playbook)
5. Rebooting nodes

## Notes

- **Downtime:** Expect 5-10 minutes of cluster downtime during migration
- **Order matters:** Always migrate control plane first, then workers
- **Backup:** The playbook creates backups of service files automatically
- **eth0 IPs:** These do NOT change - they're based on physical node position

