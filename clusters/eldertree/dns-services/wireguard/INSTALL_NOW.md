# Install WireGuard VPN Now

## Quick Install (Copy-Paste Ready)

### Step 1: Install on Raspberry Pi

SSH to your Pi first:
```bash
ssh raolivei@192.168.2.83
```

Then copy and paste this entire block:

```bash
cd /tmp && \
curl -O https://raw.githubusercontent.com/raolivei/raolivei/main/pi-fleet/clusters/eldertree/dns-services/wireguard/install-wireguard.sh && \
chmod +x install-wireguard.sh && \
sudo ./install-wireguard.sh
```

**OR** if GitHub isn't accessible, copy the script content manually:

```bash
cd /tmp
# Then paste the contents of install-wireguard.sh here
nano install-wireguard.sh
# Paste contents, save (Ctrl+X, Y, Enter)
chmod +x install-wireguard.sh
sudo ./install-wireguard.sh
```

### Step 2: Note Important Information

After installation completes, note:
1. **Server Public Key** (shown in output)
2. **Public IP** (run: `curl ifconfig.me`)

### Step 3: Configure Router (If Needed)

If behind NAT, forward UDP port `51820` to `192.168.2.83` in router settings.

### Step 4: Generate Client Configs

Back on your Mac:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/dns-services/wireguard

# If SSH works, run:
./generate-client.sh mac
./generate-client.sh mobile

# If SSH doesn't work, you'll need to:
# 1. Get server public key from Pi: sudo cat /etc/wireguard/server_public.key
# 2. Manually edit generate-client.sh with the server key
# 3. Run generate-client.sh
```

### Step 5: Connect

**Mac:**
```bash
brew install wireguard-tools qrencode
sudo cp client-mac.conf /usr/local/etc/wireguard/wg0.conf
sudo wg-quick up wg0
```

**Mobile:**
- Install WireGuard app
- Scan QR code: `open client-mobile.png`

### Step 6: Test

```bash
ping 192.168.2.83
kubectl get nodes
```

---

## Alternative: Manual Installation

If the script doesn't work, see `SETUP_INSTRUCTIONS.md` for manual steps.

