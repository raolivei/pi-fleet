# Configure WireGuard for Split-Tunnel: Cluster Networks Only

## Problem

Currently, WireGuard VPN routes both cluster traffic and LAN traffic through the VPN. This causes:

- Internet traffic to be routed through the VPN unnecessarily
- LAN traffic (192.168.2.0/24) to be routed through VPN when it should use direct connection
- Potential performance issues and unnecessary bandwidth usage

## Goal

Configure WireGuard to implement **split-tunneling** where:

- ✅ **Route through VPN**: Only Kubernetes cluster networks
  - `10.42.0.0/16` (k3s Pod network)
  - `10.43.0.0/16` (k3s Service network)
  - `10.8.0.0/24` (WireGuard tunnel network)
- ❌ **Bypass VPN**: LAN and Internet traffic
  - `192.168.2.0/24` (LAN network) - use direct connection
  - `0.0.0.0/0` (Internet) - use normal connection

This allows normal internet usage while securely accessing cluster services.

## Current State

### Server Configuration

- **File**: `clusters/eldertree/dns-services/wireguard/install-wireguard.sh`
- Uses generic `MASQUERADE` rule that routes all traffic
- Includes firewall rule allowing WireGuard to LAN

### Client Configuration

- **Files**:
  - `clusters/eldertree/dns-services/wireguard/generate-client.sh`
  - `clusters/eldertree/dns-services/wireguard/client-mac.conf`
  - `clusters/eldertree/dns-services/wireguard/client-mobile.conf`
- `AllowedIPs` includes `192.168.2.0/24` (LAN network)

### Alternative Setup

- **Files**: `clusters/eldertree/wireguard/`
- Similar issues with LAN routing

## Required Changes

### 1. Server Configuration (`install-wireguard.sh`)

**Location**: `clusters/eldertree/dns-services/wireguard/install-wireguard.sh`

**Change**: Replace generic MASQUERADE with cluster-specific NAT rules

```bash
# OLD (routes all traffic):
PostUp = iptables -t nat -A POSTROUTING -o ${DEFAULT_INTERFACE} -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o ${DEFAULT_INTERFACE} -j MASQUERADE

# NEW (only cluster networks):
PostUp = iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 10.42.0.0/16 -j MASQUERADE
PostUp = iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 10.43.0.0/16 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -d 10.42.0.0/16 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -d 10.43.0.0/16 -j MASQUERADE
```

**Also remove**: Firewall rule allowing WireGuard to LAN (line 143):

```bash
# REMOVE this line:
ufw allow from ${WG_NETWORK} to ${LOCAL_NETWORK} comment 'WireGuard to LAN'
```

### 2. Client Configuration Generator (`generate-client.sh`)

**Location**: `clusters/eldertree/dns-services/wireguard/generate-client.sh`

**Change**: Update `AllowedIPs` to only include cluster networks

```bash
# OLD (line 76):
AllowedIPs = ${WG_NETWORK}, ${LOCAL_NETWORK}

# NEW:
AllowedIPs = ${WG_NETWORK}, 10.42.0.0/16, 10.43.0.0/16
```

### 3. Existing Client Configs

**Files**:

- `clusters/eldertree/dns-services/wireguard/client-mac.conf`
- `clusters/eldertree/dns-services/wireguard/client-mobile.conf`

**Change**: Update `AllowedIPs` line

```conf
# OLD:
AllowedIPs = 10.8.0.0/24, 192.168.2.0/24

# NEW:
AllowedIPs = 10.8.0.0/24, 10.42.0.0/16, 10.43.0.0/16
```

### 4. Alternative WireGuard Setup

**Files**:

- `clusters/eldertree/wireguard/wg0.conf`
- `clusters/eldertree/wireguard/client-template.conf`
- `clusters/eldertree/wireguard/generate-client.sh`

**Changes**: Apply same updates as above for consistency

### 5. DNS Configuration

Ensure DNS forwarding is configured for cluster domains:

- Client DNS should point to WireGuard server (`10.8.0.1`)
- Server should forward `*.cluster.local` queries to CoreDNS (`10.43.0.10`)

## Implementation Steps

1. **Update server install script** (`install-wireguard.sh`)

   - Replace MASQUERADE rules with cluster-specific rules
   - Remove LAN firewall rule

2. **Update client generator** (`generate-client.sh`)

   - Remove `LOCAL_NETWORK` from `AllowedIPs`
   - Add cluster networks to `AllowedIPs`

3. **Update existing client configs**

   - `client-mac.conf`
   - `client-mobile.conf`

4. **Update alternative setup** (for consistency)

   - `wireguard/wg0.conf`
   - `wireguard/client-template.conf`
   - `wireguard/generate-client.sh`

5. **Test configuration**
   - Restart WireGuard server: `sudo systemctl restart wg-quick@wg0`
   - Update client configs on devices
   - Verify split-tunnel behavior

## Testing Checklist

After implementation, verify:

- [ ] `ip route get 10.43.0.1` routes through `wg0` (cluster service)
- [ ] `ip route get 8.8.8.8` does NOT route through `wg0` (internet)
- [ ] `ip route get 192.168.2.83` does NOT route through `wg0` (LAN)
- [ ] `kubectl get nodes` works (cluster access)
- [ ] `curl ifconfig.me` shows real public IP, not Pi's IP (internet bypass)
- [ ] `ping 192.168.2.83` works via direct LAN connection

## Network Details

- **LAN Network**: `192.168.2.0/24`
- **Pod Network**: `10.42.0.0/16` (k3s Flannel)
- **Service Network**: `10.43.0.0/16` (k3s ClusterIP)
- **WireGuard Network**: `10.8.0.0/24`
- **CoreDNS IP**: `10.43.0.10`

## Related Files

- `clusters/eldertree/dns-services/wireguard/install-wireguard.sh`
- `clusters/eldertree/dns-services/wireguard/generate-client.sh`
- `clusters/eldertree/dns-services/wireguard/client-mac.conf`
- `clusters/eldertree/dns-services/wireguard/client-mobile.conf`
- `clusters/eldertree/wireguard/wg0.conf`
- `clusters/eldertree/wireguard/client-template.conf`
- `clusters/eldertree/wireguard/generate-client.sh`
- `docs/NETWORK_ARCHITECTURE.md`

## Notes

- This is a **split-tunnel** configuration - internet and LAN traffic bypass the VPN
- Only cluster traffic (pods and services) goes through the encrypted tunnel
- DNS should be configured to resolve `*.cluster.local` domains through CoreDNS
- Existing clients will need to update their configurations after these changes

