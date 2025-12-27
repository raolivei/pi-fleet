# Recover Node-1 Network and Hostname

## Current Issues
- Hostname reverted to `node-x` after reboot
- IPs assigned but no connectivity (can't reach gateway or external)
- No SD card (booting from NVMe)

## Recovery Steps (Run on Node-1 Physical Terminal)

### Step 1: Check Current Network State

```bash
# Check current hostname
hostname
cat /etc/hostname

# Check IP assignments
ip addr show

# Check routing
ip route show

# Test connectivity
ping -c 2 192.168.2.1
ping -c 2 8.8.8.8
```

### Step 2: Check Netplan Configuration

```bash
# List all netplan files
sudo ls -la /etc/netplan/

# Check what's configured
sudo cat /etc/netplan/*.yaml
```

### Step 3: Remove Problematic Netplan Files

```bash
# Remove the dual-IP config that's causing issues
sudo rm -f /etc/netplan/01-eth0-static.yaml

# Check if there are other problematic files
ls -la /etc/netplan/
```

### Step 4: Configure Network to Match Node-0 Pattern

Node-0 uses:
- `wlan0`: Management IP via NetworkManager (DHCP)
- `eth0: Gigabit IP only (10.0.0.1)`

For node-1, we need:
- `wlan0`: Management IP (192.168.2.85) via NetworkManager
- `eth0`: Gigabit IP only (10.0.0.2)

#### Option A: Let NetworkManager handle wlan0, configure eth0 manually

```bash
# Add gigabit IP to eth0 manually (temporary, for testing)
sudo ip addr add 10.0.0.2/24 dev eth0

# Test connectivity
ping -c 2 192.168.2.1
ping -c 2 8.8.8.8
```

If this works, create a minimal netplan file:

```bash
sudo tee /etc/netplan/10-eth0-gigabit.yaml > /dev/null <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 10.0.0.2/24
      # No routes - wlan0 handles default route
      # No DNS - wlan0 handles DNS
EOF

# Set correct permissions
sudo chmod 600 /etc/netplan/10-eth0-gigabit.yaml

# Apply
sudo netplan generate
sudo netplan apply
```

#### Option B: If wlan0 is not getting IP automatically

Check NetworkManager status:
```bash
sudo systemctl status NetworkManager
sudo nmcli device status
sudo nmcli connection show
```

If wlan0 needs manual configuration, you can temporarily use netplan for both:

```bash
# Backup existing configs
sudo mkdir -p /root/netplan-backup
sudo cp /etc/netplan/*.yaml /root/netplan-backup/ 2>/dev/null || true

# Create minimal config for eth0 only
sudo tee /etc/netplan/10-eth0-gigabit.yaml > /dev/null <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 10.0.0.2/24
EOF

sudo chmod 600 /etc/netplan/10-eth0-gigabit.yaml

# Let NetworkManager handle wlan0 (don't create netplan for it)
# Apply eth0 config
sudo netplan generate
sudo netplan apply
```

### Step 5: Fix Hostname

```bash
# Set hostname
sudo hostnamectl set-hostname node-1.eldertree.local

# Update /etc/hostname
echo "node-1.eldertree.local" | sudo tee /etc/hostname

# Update /etc/hosts
sudo sed -i 's/^127\.0\.1\.1.*/127.0.1.1 node-1.eldertree.local node-1/' /etc/hosts

# Verify
hostname
cat /etc/hostname
```

### Step 6: Verify Network After Changes

```bash
# Wait a few seconds for network to stabilize
sleep 5

# Check IPs
ip addr show eth0 | grep "inet "
ip addr show wlan0 | grep "inet "

# Check routing
ip route show

# Test connectivity
ping -c 2 192.168.2.1
ping -c 2 8.8.8.8
ping -c 2 www.google.com
```

### Step 7: If Still No Connectivity

If wlan0 doesn't have an IP:

```bash
# Check NetworkManager
sudo systemctl status NetworkManager
sudo nmcli device status

# Try to connect wlan0 manually
sudo nmcli device wifi list  # List available networks
sudo nmcli device wifi connect "homebase" password "YOUR_PASSWORD"  # Replace with actual password

# Or check if there's a saved connection
sudo nmcli connection show
sudo nmcli connection up "netplan-wlan0-homebase"  # If it exists
```

### Step 8: Once Connectivity is Restored

From your local machine, run:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet

# Test connection
ansible node-1 -i ansible/inventory/hosts.yml -m ping

# Fix hostname properly
ansible-playbook ansible/playbooks/setup-system.yml --limit node-1 -e "hostname=node-1.eldertree.local"

# Verify k3s-agent
ansible node-1 -i ansible/inventory/hosts.yml -m shell -a "sudo systemctl status k3s-agent --no-pager | head -20" --become
```

## Expected Final State

- **Hostname**: `node-1.eldertree.local`
- **wlan0**: `192.168.2.85/24` (via NetworkManager)
- **eth0**: `10.0.0.2/24` (via netplan or manual)
- **Default route**: Via `wlan0` to `192.168.2.1`
- **Connectivity**: Can ping gateway and external (8.8.8.8, google.com)

## Troubleshooting

### If eth0 and wlan0 both have IPs but no connectivity:

```bash
# Check for routing conflicts
ip route show

# Check if default route is correct
ip route get 8.8.8.8

# Manually set default route if needed
sudo ip route del default 2>/dev/null || true
sudo ip route add default via 192.168.2.1 dev wlan0
```

### If NetworkManager is interfering:

```bash
# Check NetworkManager managed devices
sudo nmcli device status

# If eth0 is managed by NetworkManager, unmanage it
sudo nmcli device set eth0 managed no

# Then apply netplan
sudo netplan apply
```

### If nothing works, minimal recovery:

```bash
# Remove all netplan configs
sudo rm -f /etc/netplan/01-*.yaml /etc/netplan/10-*.yaml

# Let NetworkManager handle everything via DHCP
sudo netplan generate
sudo netplan apply

# Manually add eth0 IP
sudo ip addr add 10.0.0.2/24 dev eth0

# Test
ping -c 2 192.168.2.1
```

Once basic connectivity is restored, we can properly configure it via Ansible.

