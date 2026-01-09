# Fix Nodes After Netplan Configuration Issue

## Current Situation

Both nodes (node-0 and node-1) are unreachable due to incorrect Netplan static IP configuration.

## Recovery Instructions

### Step 1: Physical Access to Nodes

Connect keyboard and monitor to each node.

### Step 2: Fix Netplan Configuration

For **node-0**:

```bash
sudo nano /etc/netplan/01-netcfg.yaml
```

Set content to:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.2.80/24
      gateway4: 192.168.2.1
      nameservers:
        addresses: [192.168.2.1, 8.8.8.8]
```

For **node-1**:

```bash
sudo nano /etc/netplan/01-netcfg.yaml
```

Set content to:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.2.81/24
      gateway4: 192.168.2.1
      nameservers:
        addresses: [192.168.2.1, 8.8.8.8]
```

### Step 3: Apply Configuration

On each node:

```bash
sudo netplan apply
```

### Step 4: Verify

On each node:

```bash
# Check IP address
ip addr show eth0 | grep 'inet '

# Test connectivity
ping -c 2 192.168.2.1

# Check hostname
hostname
# Should show: node-0.eldertree.local or node-1.eldertree.local
```

### Step 5: Fix Hostname (if needed)

If hostname shows "eldertree" instead of "node-X.eldertree.local":

```bash
# Set correct hostname
sudo hostnamectl set-hostname node-0.eldertree.local  # For node-0
# OR
sudo hostnamectl set-hostname node-1.eldertree.local  # For node-1

# Update /etc/hostname
echo "node-0.eldertree.local" | sudo tee /etc/hostname  # For node-0
# OR
echo "node-1.eldertree.local" | sudo tee /etc/hostname  # For node-1

# Update /etc/hosts
sudo sed -i 's/^127\.0\.1\.1.*/127.0.1.1 node-0.eldertree.local node-0/' /etc/hosts  # For node-0
# OR
sudo sed -i 's/^127\.0\.1\.1.*/127.0.1.1 node-1.eldertree.local node-1/' /etc/hosts  # For node-1

# Reboot to apply
sudo reboot
```

### Step 6: Verify from Local Machine

After nodes reboot:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible

# Test connectivity
ansible raspberry_pi -m ping

# Verify hostnames
ansible raspberry_pi -m shell -a "hostname"

# Verify IPs
ansible raspberry_pi -m shell -a "ip addr show eth0 | grep 'inet '"
```

Expected output:

- node-0: `node-0.eldertree.local`, IP: `192.168.2.80`
- node-1: `node-1.eldertree.local`, IP: `192.168.2.81`

## What Was Fixed

1. **Hostname validation** - Playbooks now prevent setting hostname to just "eldertree"
2. **Static IP auto-calculation** - IPs automatically assigned: node-0 = 192.168.2.80, node-1 = 192.168.2.81
3. **Documentation** - Added IP assignment pattern documentation

## Next Steps

Once nodes are reachable:

1. **Update inventory** - Already updated to use new IPs (192.168.2.80, 192.168.2.81)
2. **Continue cluster rebuild** - Run `ansible-playbook playbooks/rebuild-cluster.yml`

## Related Documentation

- [Node IP Assignment](./NODE_IP_ASSIGNMENT.md)
- [Recover Network Connectivity](./RECOVER_NETWORK_CONNECTIVITY.md)






