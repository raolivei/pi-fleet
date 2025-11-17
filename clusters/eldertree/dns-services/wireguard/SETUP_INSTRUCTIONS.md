# WireGuard VPN Setup Instructions

Follow these steps to set up WireGuard VPN:

## Step 1: Install WireGuard on Raspberry Pi

SSH to your Pi and run:

```bash
# Option A: Copy script to Pi and run
scp install-wireguard.sh raolivei@192.168.2.83:/tmp/
ssh raolivei@192.168.2.83
cd /tmp
sudo bash install-wireguard.sh

# Option B: Download directly on Pi
ssh raolivei@192.168.2.83
cd /tmp
curl -O https://raw.githubusercontent.com/raolivei/raolivei/main/pi-fleet/clusters/eldertree/infrastructure/wireguard/install-wireguard.sh
chmod +x install-wireguard.sh
sudo ./install-wireguard.sh
```

**Note:** The script will:
- Install WireGuard packages
- Generate server keys
- Configure networking
- Start WireGuard service
- Set up firewall rules

**Save the server public key** - you'll see it in the output:
```
📋 Server Public Key: <KEY_HERE>
```

## Step 2: Configure Router Port Forwarding (If Behind NAT)

If your Pi is behind a router:

1. Log into router admin panel (usually `192.168.2.1` or `192.168.1.1`)
2. Find "Port Forwarding" or "Virtual Server"
3. Add rule:
   - **Protocol**: UDP
   - **External Port**: 51820
   - **Internal IP**: 192.168.2.83
   - **Internal Port**: 51820
4. Save and apply

## Step 3: Get Your Public IP

On the Pi, run:
```bash
curl ifconfig.me
```

Note this IP address - you'll need it for client configs.

## Step 4: Generate Client Configurations

Back on your Mac, run:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/infrastructure/wireguard

# Update PUBLIC_IP in generate-client.sh if needed, then:
./generate-client.sh mac
./generate-client.sh mobile
```

If the script can't SSH automatically, it will show you the peer config to add manually.

## Step 5: Connect from Mac

```bash
# Install WireGuard (if not installed)
brew install wireguard-tools qrencode

# Copy config
sudo mkdir -p /usr/local/etc/wireguard
sudo cp client-mac.conf /usr/local/etc/wireguard/wg0.conf

# Start VPN
sudo wg-quick up wg0

# Check status
sudo wg show
```

## Step 6: Connect from Mobile

1. Install WireGuard app (iOS/Android)
2. Open app → Tap "+" → "Create from QR code"
3. Scan `client-mobile.png` QR code
4. Tap "Add" → Toggle switch to connect

## Step 7: Test Connection

```bash
# Ping cluster
ping 192.168.2.83

# Access Kubernetes
kubectl get nodes

# Access services
curl -k https://canopy.eldertree.local/api/v1/health
```

## Troubleshooting

### Can't SSH to Pi
- Make sure you're on the same network
- Check SSH keys are set up: `ssh-copy-id raolivei@192.168.2.83`
- Or use password: `ssh raolivei@192.168.2.83`

### Script Fails
- Run with verbose output: `bash -x install-wireguard.sh`
- Check logs: `sudo journalctl -u wg-quick@wg0 -n 50`

### Can't Connect VPN
- Check firewall: `sudo ufw status` (should allow UDP 51820)
- Check WireGuard status: `sudo systemctl status wg-quick@wg0`
- Verify port forwarding on router

### Can't Access Services
- Check routing: `ip route | grep 192.168.2`
- Check DNS: `nslookup canopy.eldertree.local`
- Verify WireGuard handshake: `sudo wg show` (should show recent handshake times)

