# Adding a Worker Node to Eldertree Cluster

Complete guide for adding a new Raspberry Pi as a worker node to your k3s cluster.

## Prerequisites

### 1. Hardware Requirements

- ✅ Raspberry Pi 5 (8GB recommended, ARM64)
- ✅ MicroSD card (32GB+ recommended, Class 10 or better)
- ✅ Power supply for Raspberry Pi 5
- ✅ Ethernet cable (connected to TP-Link SG105 switch)
- ✅ SD card reader/adapter for your Mac

### 2. Software Requirements

- ✅ Raspberry Pi Imager installed on your Mac
- ✅ Ansible, kubectl, sshpass installed on your Mac
- ✅ Existing eldertree cluster running and accessible

## Step 1: Install Operating System

**⚠️ CRITICAL**: The new Pi **MUST** have an OS installed before you can add it to the cluster.

### Quick OS Installation

1. **Install Raspberry Pi Imager** (if not installed):

   ```bash
   brew install --cask raspberry-pi-imager
   ```

2. **Open Raspberry Pi Imager**:

   ```bash
   open -a "Raspberry Pi Imager"
   ```

3. **Choose Operating System**:

   - Click **"Choose OS"**
   - Navigate to: **"Other general-purpose OS"** → **"Debian"** → **"Debian Bookworm (64-bit)"** or **"Debian Trixie (64-bit)"**
   - (Both work fine - Trixie is newer, Bookworm matches existing docs)

4. **Choose Storage**:

   - Click **"Choose Storage"**
   - Select your microSD card
   - **⚠️ WARNING**: This will erase everything on the SD card!

5. **Configure Settings** (Click gear icon ⚙️):

   - ✅ **Enable SSH**: **MUST BE CHECKED**
   - **Set username**: `pi` (default)
   - **Set password**: `raspberry` (or choose your own - remember it!)
   - **WiFi** (optional): If using WiFi, enter credentials
   - Click **"Save"**

6. **Write to SD Card**:

   - Click **"Write"**
   - Wait for completion (5-10 minutes)
   - Eject SD card safely

7. **Boot the Pi**:
   - Insert microSD card into Raspberry Pi
   - Connect Ethernet cable to TP-Link SG105 switch
   - Connect power supply
   - Wait for boot (30-60 seconds)
   - The Pi will automatically get an IP address via DHCP

## Step 2: Find the New Pi's IP Address

The new Pi will get an IP via DHCP. To find it:

### Option 1: Check Router Admin Panel

- Access your router's admin interface
- Look for DHCP client list
- Find device named `raspberrypi` or check MAC addresses

### Option 2: Scan Network

```bash
# From your Mac
nmap -sn 192.168.2.0/24 | grep -B 2 "Raspberry Pi"
```

### Option 3: Use mDNS (if available)

```bash
ping raspberrypi.local
```

### Option 4: Check Switch/Network

Since both Pis are on the TP-Link SG105 switch, check which IPs are active:

```bash
# Check which IPs respond to ping
for ip in {1..254}; do
  ping -c 1 -W 1 192.168.2.$ip &>/dev/null && echo "192.168.2.$ip is up"
done | grep -v "192.168.2.86"  # Exclude eldertree (node-0)
```

## Step 3: Add Worker Node to Cluster

Once you have the IP address, use the automated script:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet

# Basic usage (with DHCP IP)
./scripts/setup/add-worker-node.sh <ip-address> fleet-worker-01

# With static IP assignment
./scripts/setup/add-worker-node.sh <ip-address> fleet-worker-01 <static-ip>
```

### Example

```bash
# If new Pi got IP via DHCP (check router or use hostname)
./scripts/setup/add-worker-node.sh <new-pi-ip> <hostname>

# Example: If new Pi got IP 192.168.2.87 via DHCP
./scripts/setup/add-worker-node.sh 192.168.2.87 node-2
```

### What the Script Does

1. ✅ Tests connectivity to the new Pi
2. ✅ Checks SSH access (prompts for password if needed)
3. ✅ Retrieves k3s node token from control plane
4. ✅ Updates Ansible inventory
5. ✅ Configures system (hostname, user, network, packages)
6. ✅ Installs k3s as worker node
7. ✅ Verifies the node joined the cluster

### During Setup

You'll be prompted for:

- SSH password (default: `raspberry` if using default Pi OS setup)
- Sudo password (same as SSH password)

## Step 4: Verify Worker Node

After setup completes, verify the node joined:

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
```

You should see both nodes:

```
NAME            STATUS   ROLES                       AGE   VERSION
eldertree       Ready    control-plane,etcd,master   3d    v1.33.5+k3s1
fleet-worker-01 Ready    <none>                      5m    v1.33.5+k3s1
```

## Troubleshooting

### "Cannot reach IP address"

- Ensure Pi is powered on
- Check Ethernet cable is connected to switch
- Verify switch is powered and working
- Check router DHCP is assigning IPs

### "SSH connection refused"

- Ensure SSH was enabled in Raspberry Pi Imager settings
- Wait a bit longer for Pi to finish booting
- Try: `ssh pi@<ip-address>` manually first

### "k3s worker not joining cluster"

- Check worker can reach control plane: `ping eldertree` from worker
- Verify k3s token is correct
- Check logs: `ssh pi@<worker-ip> "sudo journalctl -u k3s-agent -n 50"`

### "Node appears but status is NotReady"

- Wait a few minutes for node to fully initialize
- Check: `kubectl describe node fleet-worker-01`
- Verify network connectivity between nodes

## Worker Node Naming Convention

Follow this pattern for worker nodes:

- `fleet-worker-01` - First worker
- `fleet-worker-02` - Second worker
- `fleet-worker-03` - Third worker
- etc.

## Next Steps

After adding the worker node:

1. **Verify pods can schedule on worker**:

   ```bash
   kubectl get pods -A -o wide
   ```

2. **Check node resources**:

   ```bash
   kubectl top nodes
   ```

3. **Optional: Configure static IP** (if using DHCP):
   - Update router DHCP reservation
   - Or configure static IP in the setup script

## Manual Setup (Alternative)

If you prefer manual setup instead of the automated script:

```bash
# 1. Get k3s token from control plane
cat ~/WORKSPACE/raolivei/pi-fleet/ansible/k3s-node-token

# 2. SSH to new worker node
ssh pi@<worker-ip>

# 3. Install k3s worker
curl -sfL https://get.k3s.io | K3S_URL=https://eldertree:6443 K3S_TOKEN=<token> sh -
```

But the automated script handles system configuration, hostname, user setup, etc., so it's recommended.
