# Gigabit Network Setup for Eldertree Cluster

## ✅ Working Configuration: Isolated Switch with Separate Subnet

This is the **working solution** for configuring gigabit Ethernet (eth0) for direct node-to-node communication via an isolated switch.

## Problem Statement

- **Switch is isolated** - Not connected to router, only connects the two Pis
- **Goal**: Configure `eth0` on both nodes for gigabit node-to-node communication
- **Constraint**: Must not break existing internet connectivity (via wlan0)

## ✅ Solution: Separate Subnet for Isolated Switch

### Strategy

1. **Use different subnet for eth0** - Avoids conflicts with router network
2. **No gateway on eth0** - Preserves wlan0 default route for internet
3. **No DNS on eth0** - System uses wlan0 DNS
4. **Static IPs on isolated network** - Safe because switch isn't connected to router

### Network Configuration

**node-1 (eldertree):**
- `wlan0`: `192.168.2.86/24` (primary, default route via `192.168.2.1` for internet)
- `eth0`: `10.0.0.1/24` (static IP, no gateway, for direct gigabit connection)

**node-1:**
- `wlan0`: `192.168.2.85/24` (primary, default route for internet)
- `eth0`: `10.0.0.2/24` (static IP, no gateway, for direct gigabit connection)

### Key Principles

1. **Different subnet** - `10.0.0.0/24` for eth0, `192.168.2.0/24` for wlan0
2. **No gateway on eth0** - Cannot break internet connectivity
3. **No DNS on eth0** - Uses system DNS from wlan0
4. **Isolated network** - Safe to use static IPs since switch isn't on router network

## Implementation

### Step 1: Configure node-1 eth0

```bash
ssh raolivei@192.168.2.86

sudo tee /etc/netplan/02-eth0-static.yaml > /dev/null <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 10.0.0.1/24
      # No gateway4 - wlan0 keeps default route for internet
      # No nameservers - system uses wlan0 DNS
EOF

sudo chmod 600 /etc/netplan/02-eth0-static.yaml
sudo netplan apply
```

### Step 2: Configure node-1 eth0

```bash
ssh raolivei@192.168.2.85

sudo tee /etc/netplan/02-eth0-static.yaml > /dev/null <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 10.0.0.2/24
      # No gateway4 - wlan0 keeps default route for internet
      # No nameservers - system uses wlan0 DNS
EOF

sudo chmod 600 /etc/netplan/02-eth0-static.yaml
sudo netplan apply
```

### Step 3: Verify Configuration

```bash
# Check eth0 IPs
ip addr show eth0 | grep "inet "

# Should show:
# node-1: inet 10.0.0.1/24
# node-1: inet 10.0.0.2/24

# Test connectivity via eth0
ping -c 2 -I eth0 10.0.0.2  # From node-1
ping -c 2 -I eth0 10.0.0.1  # From node-1

# Verify internet still works
ping -c 2 google.com
```

## Usage in Backup Scripts

The backup script (`scripts/storage/backup-eldertree-to-node1-nvme.sh`) uses:
- **wlan0 IPs** (192.168.2.86/192.168.2.85) for SSH access
- **eth0 IPs** (10.0.0.1/10.0.0.2) for data transfer via gigabit switch

This provides:
- Reliable SSH access via router network
- Fast data transfer via isolated gigabit switch

## Verification

After configuration, verify:

```bash
# Check eth0 has correct IP
ip addr show eth0 | grep "inet "

# Check default route (should still be wlan0)
ip route show default

# Test node-to-node connectivity via eth0
ping -c 2 -I eth0 10.0.0.2  # From node-1
ping -c 2 -I eth0 10.0.0.1  # From node-1

# Verify internet still works
ping -c 2 google.com
```

## Troubleshooting

### If connectivity is lost:

1. **Remove eth0 config:**
   ```bash
   sudo rm /etc/netplan/02-eth0-static.yaml
   sudo netplan apply
   ```

2. **Check default route:**
   ```bash
   ip route show default
   # Should show wlan0, not eth0
   ```

3. **Restart network:**
   ```bash
   sudo systemctl restart systemd-networkd
   ```

### If eth0 doesn't get IP:

1. **Check netplan syntax:**
   ```bash
   sudo netplan --debug apply
   ```

2. **Check interface status:**
   ```bash
   ip link show eth0
   # Should show: state UP
   ```

3. **Check logs:**
   ```bash
   journalctl -u systemd-networkd | tail -20
   ```

## Safety Features

- **Different subnet** - No conflicts with router network
- **No default route on eth0** - Cannot break internet
- **No DNS changes** - Cannot break DNS resolution
- **Isolated network** - Safe to use static IPs
- **Reversible** - Easy to remove configuration

## Why This Works

1. **Isolated switch** - Not connected to router, so static IPs are safe
2. **Separate subnet** - `10.0.0.0/24` doesn't conflict with `192.168.2.0/24`
3. **No gateway** - eth0 can't interfere with wlan0's default route
4. **Direct connection** - Traffic between 10.0.0.1 and 10.0.0.2 uses gigabit switch

## Performance

- **Latency**: ~0.2ms between nodes via eth0
- **Speed**: Full gigabit (1000 Mbps) for node-to-node transfers
- **Internet**: Preserved via wlan0

## Summary

**Working Configuration:**
- eth0 uses separate subnet (10.0.0.0/24) for isolated switch
- wlan0 keeps internet connectivity (192.168.2.0/24)
- No gateway or DNS on eth0
- Safe and reversible

**This is the tested and working solution for isolated switch setup.**
