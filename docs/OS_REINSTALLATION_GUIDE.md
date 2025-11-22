# OS Reinstallation Guide - Eldertree Cluster

Complete guide for reinstalling the OS on the Raspberry Pi and restoring the cluster using Ansible, Terraform, and Helm.

## Overview

This guide covers:

1. **Pre-installation**: What to preserve/backup
2. **OS Installation**: Fresh Debian 12 Bookworm installation
3. **Post-installation**: Automated setup using Ansible, Terraform, and Helm
4. **Cluster Restoration**: Deploying all services via GitOps

## Prerequisites

- Raspberry Pi 5 (8GB, ARM64)
- MicroSD card (32GB+ recommended)
- USB backup drive (for backups)
- Access to the Pi via SSH or console
- Mac/Linux machine with:
  - Ansible installed
  - Terraform installed
  - kubectl installed
  - sshpass installed (`brew install hudochenkov/sshpass/sshpass`)

## Step 1: Pre-Installation Backup

### Critical Data to Backup

Before reinstalling, ensure you have backups of:

1. **Vault Secrets** (if not already backed up):

   ```bash
   # From your Mac, if Pi is still accessible
   export KUBECONFIG=~/.kube/config-eldertree
   kubectl exec -n vault $(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}') -- \
     sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN=root && vault kv list -format=json secret/" > vault-secrets-backup.json
   ```

2. **Kubernetes Resources** (if needed):

   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   kubectl get all -A -o yaml > k8s-resources-backup.yaml
   ```

3. **System Configuration** (if you want to preserve):
   - `/etc/fstab` - Mount points
   - `/etc/hostname` - Hostname
   - `/etc/hosts` - Host entries
   - Network configuration (if using static IP)
   - SSH keys (if any)

### USB Backup Drive

If you have backups on USB drive, ensure it's accessible. The backup drive should be formatted as ext4 and will be mounted at `/mnt/backup` after setup.

## Step 2: OS Installation

**⚠️ IMPORTANT**: This is the first step - you need to flash a fresh OS to the SD card before running any automation.

### Choose Your OS

You have two options:

1. **Debian 12 Bookworm (64-bit)** - Recommended (what the cluster currently uses)

   - More minimal, faster boot
   - Better for server workloads
   - Location in Imager: "Other general-purpose OS" → "Debian" → "Debian Bookworm (64-bit)"

2. **Raspberry Pi OS (64-bit)** - Alternative
   - More user-friendly, includes desktop tools
   - Location in Imager: "Raspberry Pi OS (other)" → "Raspberry Pi OS (64-bit)"

**Recommendation**: Use **Debian 12 Bookworm** to match the current cluster setup.

### Step-by-Step: Flash OS to SD Card

1. **Install Raspberry Pi Imager** (if not already installed):

   ```bash
   # macOS
   brew install --cask raspberry-pi-imager

   # Or download from: https://www.raspberrypi.com/software/
   ```

2. **Prepare SD Card**:

   - Insert microSD card into your Mac (using adapter if needed)
   - **⚠️ WARNING**: This will erase everything on the SD card!

3. **Open Raspberry Pi Imager**:

   - Launch the application

4. **Choose Operating System**:

   - Click **"Choose OS"**
   - Navigate to: **"Other general-purpose OS"** → **"Debian"** → **"Debian Bookworm (64-bit)"**
   - (Or choose Raspberry Pi OS if preferred)

5. **Choose Storage**:

   - Click **"Choose Storage"**
   - Select your microSD card
   - **⚠️ Double-check** you selected the right drive!

6. **Configure Settings** (Click the gear icon ⚙️):

   **Essential Settings**:

   - ✅ **Enable SSH**: Check this box
   - **Set username**: `pi`
   - **Set password**: `raspberry` (or choose your own - you'll need it for SSH)
   - **Configure wireless LAN** (optional): If using WiFi, enter credentials here

   **Optional Settings**:

   - **Set locale settings**: Timezone (e.g., `America/Toronto`), keyboard layout
   - **Set hostname**: Leave as default (`raspberrypi`) - we'll change it later

   Click **"Save"**

7. **Write to SD Card**:

   - Click **"Write"**
   - Confirm when prompted
   - Wait for writing to complete (may take 5-10 minutes)
   - Click **"Continue"** when done

8. **Eject SD Card**:

   - Safely eject the SD card from your Mac

9. **Boot the Pi**:
   - Insert microSD card into Raspberry Pi
   - Connect power supply
   - Wait for boot (LED should stop blinking after 30-60 seconds)
   - The Pi will automatically get an IP address via DHCP

### Initial Network Setup

The Pi should get an IP via DHCP. To find it:

```bash
# Option 1: Check router admin panel
# Look for device named "raspberrypi" or check DHCP leases

# Option 2: Scan network (from Mac)
nmap -sn 192.168.2.0/24 | grep -B 2 "Raspberry Pi"

# Option 3: Use mDNS (if available)
ping raspberrypi.local
```

Default hostname will be `raspberrypi`. We'll change it to `eldertree` during setup.

## Step 3: Post-Installation Setup

### Quick Setup (Automated)

Run the complete setup script from your Mac:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet
./scripts/setup-eldertree.sh
```

This script will:

1. Configure system settings via Ansible
2. Install k3s via Terraform
3. Bootstrap FluxCD GitOps
4. Deploy all services

### Manual Setup (Step-by-Step)

#### 3.1: Initial SSH Access

```bash
# SSH to Pi (default credentials)
ssh pi@<PI_IP_ADDRESS>
# Password: raspberry (or what you set in Imager)

# Update system
sudo apt update && sudo apt upgrade -y
sudo reboot
```

#### 3.2: Configure System with Ansible

From your Mac:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible

# Update inventory with Pi's IP address
# Edit inventory/hosts.yml and set ansible_host to your Pi's IP

# Run system setup playbook
ansible-playbook playbooks/setup-system.yml \
  --ask-pass \
  --ask-become-pass

# This will:
# - Set hostname to 'eldertree'
# - Create raolivei user (password set via Ansible Vault)
# - Configure SSH keys
# - Set up static IP (if configured)
# - Configure Bluetooth
# - Set up backup mount with nofail
# - Install prerequisites
```

#### 3.3: Install k3s with Terraform

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/terraform

# Copy terraform variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars:
# - pi_host: "eldertree" (or IP address)
# - pi_user: "raolivei"
# - pi_password: "your-password-here" (DO NOT commit this file to git)

# Initialize and apply
terraform init
terraform apply

# This will:
# - Install k3s control plane
# - Configure kubeconfig at ~/.kube/config-eldertree
# - Install k9s
```

#### 3.4: Verify k3s Installation

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
kubectl get pods -A
```

## Step 4: Cluster Restoration

### 4.1: Bootstrap FluxCD GitOps

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Install Flux CLI (if not installed)
brew install fluxcd/tap/flux

# Bootstrap Flux
flux bootstrap github \
  --owner=raolivei \
  --repository=raolivei \
  --branch=main \
  --path=clusters/eldertree \
  --personal

# This will:
# - Install Flux components
# - Create GitHub repository sync
# - Deploy all manifests from clusters/eldertree/
```

### 4.2: Restore Vault Secrets

If you backed up Vault secrets:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Wait for Vault to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault --timeout=300s

# Unseal Vault (get unseal keys from backup or generate new)
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Unseal (replace with your unseal keys)
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && vault operator unseal <UNSEAL_KEY_1>"
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && vault operator unseal <UNSEAL_KEY_2>"
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && vault operator unseal <UNSEAL_KEY_3>"

# Restore secrets from backup (if you have one)
# See: scripts/restore-vault-secrets.sh
```

### 4.3: Deploy Applications

Applications will be deployed automatically via FluxCD GitOps from `clusters/eldertree/`. Monitor deployment:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check Flux status
flux get all

# Watch pods
kubectl get pods -A -w

# Check specific namespaces
kubectl get pods -n swimto
kubectl get pods -n canopy
kubectl get pods -n observability
```

### 4.4: Restore Backup Mount

If you have a USB backup drive:

```bash
# SSH to Pi
ssh raolivei@eldertree.local

# Check if USB drive is detected
lsblk | grep sdb

# Mount manually (if needed)
sudo mount /dev/sdb1 /mnt/backup

# Verify fstab has nofail option (should be set by Ansible)
cat /etc/fstab | grep backup
# Should show: defaults,nofail
```

## Step 5: Verification

### System Checks

```bash
# SSH to Pi
ssh raolivei@eldertree.local

# Check hostname
hostname
# Should output: eldertree

# Check Bluetooth
systemctl status bluetooth
bluetoothctl show

# Check backup mount (if USB connected)
df -h /mnt/backup

# Check k3s
sudo k3s kubectl get nodes
```

### Cluster Checks

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check nodes
kubectl get nodes

# Check all pods
kubectl get pods -A

# Check services
kubectl get svc -A

# Check ingress
kubectl get ingress -A

# Test services
curl -k https://grafana.eldertree.local
curl -k https://swimto.eldertree.local
```

## Troubleshooting

### SSH Access Issues

If you can't SSH:

1. **Check network connectivity**:

   ```bash
   ping <PI_IP>
   ```

2. **Check SSH service**:

   ```bash
   # From Pi console (if accessible)
   sudo systemctl status ssh
   sudo systemctl start ssh
   ```

3. **Check firewall**:
   ```bash
   sudo ufw status
   sudo ufw allow ssh
   ```

### Ansible Connection Issues

```bash
# Test connection
ansible all -m ping

# Use verbose output
ansible-playbook playbooks/setup-system.yml -vvv

# Check SSH key
ssh -v pi@<PI_IP>
```

### Terraform Issues

```bash
# Check Terraform state
terraform show

# Re-run if needed
terraform apply -refresh=true

# Destroy and recreate (if needed)
terraform destroy
terraform apply
```

### k3s Issues

```bash
# Check k3s service
sudo systemctl status k3s

# Check logs
sudo journalctl -u k3s -f

# Restart k3s
sudo systemctl restart k3s
```

### FluxCD Issues

```bash
# Check Flux status
flux get all

# Check Flux logs
kubectl logs -n flux-system -l app=helm-controller

# Reconcile manually
flux reconcile source git flux-system
flux reconcile kustomization flux-system
```

## What Gets Preserved vs Rebuilt

### Preserved (from backups):

- ✅ Vault secrets (if backed up)
- ✅ Application data (if on USB backup drive)
- ✅ Kubernetes manifests (in Git)
- ✅ Helm chart configurations (in Git)
- ✅ Terraform state (optional, can recreate)

### Rebuilt (fresh install):

- ✅ OS and system packages
- ✅ k3s cluster (fresh installation)
- ✅ System users and permissions
- ✅ Network configuration
- ✅ System services (Bluetooth, etc.)

## Next Steps

After successful reinstallation:

1. **Update DNS**: Ensure `/etc/hosts` entries are correct on your Mac
2. **Test Services**: Verify all applications are accessible
3. **Monitor Logs**: Check for any errors in pod logs
4. **Run Backups**: Set up automated backups again
5. **Update Documentation**: Note any changes or issues encountered

## Related Documentation

- [Boot Fix Guide](./BOOT_FIX.md) - Fixing boot issues
- [Backup Strategy](./BACKUP_STRATEGY.md) - Backup procedures
- [Network Configuration](../NETWORK.md) - DNS and networking
- [Vault Quick Reference](./VAULT_QUICK_REFERENCE.md) - Vault operations
