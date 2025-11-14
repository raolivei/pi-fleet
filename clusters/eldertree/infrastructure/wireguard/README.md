# WireGuard VPN Setup

WireGuard VPN allows secure remote access to your Kubernetes cluster from anywhere, including mobile LTE networks.

## Architecture

- **Server**: Runs on Raspberry Pi host (`eldertree` at `192.168.2.83`)
- **VPN Network**: `10.8.0.0/24` (WireGuard subnet)
- **Port**: UDP `51820`
- **Access**: Full access to local network `192.168.2.0/24` and cluster services

## Quick Start

### 1. Install WireGuard on Raspberry Pi

SSH to your Pi and run:

```bash
ssh raolivei@eldertree
cd /tmp
curl -O https://raw.githubusercontent.com/raolivei/raolivei/main/pi-fleet/clusters/eldertree/infrastructure/wireguard/install-wireguard.sh
chmod +x install-wireguard.sh
sudo ./install-wireguard.sh
```

### 2. Generate Client Configurations

On your Mac, run:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/infrastructure/wireguard
./generate-client.sh mac
./generate-client.sh mobile
```

This will create:

- `client-mac.conf` - For macOS
- `client-mobile.conf` - For iOS/Android

### 3. Install Client Configurations

#### macOS

```bash
# Copy config to WireGuard directory
sudo mkdir -p /usr/local/etc/wireguard
sudo cp client-mac.conf /usr/local/etc/wireguard/wg0.conf

# Install WireGuard (if not installed)
brew install wireguard-tools

# Start WireGuard
sudo wg-quick up wg0

# Check status
sudo wg show
```

#### iOS/Android

1. Install WireGuard app from App Store/Play Store
2. Scan QR code or import `client-mobile.conf`
3. Connect to VPN

### 4. Test Connection

```bash
# From your Mac (with VPN connected)
ping 192.168.2.83
kubectl get nodes
curl -k https://canopy.eldertree.local/api/v1/health
```

## Client Management

### Add New Client

```bash
./generate-client.sh <client-name>
```

### List All Clients

```bash
ssh raolivei@eldertree "sudo wg show"
```

### Remove Client

```bash
ssh raolivei@eldertree "sudo wg set wg0 peer <PUBLIC_KEY> remove"
```

## Troubleshooting

### VPN Not Connecting

1. **Check server status**:

   ```bash
   ssh raolivei@eldertree "sudo systemctl status wg-quick@wg0"
   ```

2. **Check firewall**:

   ```bash
   ssh raolivei@eldertree "sudo ufw status"
   # Should allow UDP 51820
   ```

3. **Check WireGuard logs**:
   ```bash
   ssh raolivei@eldertree "sudo journalctl -u wg-quick@wg0 -f"
   ```

### Can't Access Cluster Services

1. **Check routing**:

   ```bash
   # On client
   ip route | grep 192.168.2
   ```

2. **Check DNS**:
   ```bash
   # Should resolve to VPN DNS or Pi-hole
   nslookup canopy.eldertree.local
   ```

### Port Forwarding (Router)

If your router has a firewall, forward UDP port `51820` to `192.168.2.83`.

## Security Notes

- WireGuard uses modern cryptography (ChaCha20, Poly1305, Curve25519)
- Keys are generated securely on the server
- Each client has a unique key pair
- Server public key is shared with clients
- Client public keys are added to server config

## Network Access

Once connected, you can access:

- **Kubernetes API**: `https://192.168.2.83:6443` or `https://eldertree:6443`
- **Cluster Services**: `https://canopy.eldertree.local`, `https://pihole.eldertree.local`, etc.
- **SSH**: `ssh raolivei@192.168.2.83`
- **Local Network**: All devices on `192.168.2.0/24`

## Configuration Files

- `server.conf` - Server configuration (on Pi at `/etc/wireguard/wg0.conf`)
- `client-*.conf` - Client configurations (one per device)
- `install-wireguard.sh` - Installation script
- `generate-client.sh` - Client config generator
