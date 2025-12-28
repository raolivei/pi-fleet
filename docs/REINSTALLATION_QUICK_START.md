# Quick Start - OS Reinstallation

Fast reference for reinstalling the OS and restoring the eldertree cluster.

## Prerequisites

- Raspberry Pi Imager installed
- MicroSD card ready
- USB backup drive (if restoring backups)
- Mac/Linux machine with Ansible, Terraform, kubectl, flux CLI

## Step 1: Flash OS to SD Card

**⚠️ FIRST STEP**: Flash a fresh OS before running automation!

1. **Install Raspberry Pi Imager** (if needed):

   ```bash
   brew install --cask raspberry-pi-imager
   ```

2. **Open Raspberry Pi Imager**

3. **Choose OS**:

   - Click "Choose OS"
   - Navigate to: **"Other general-purpose OS"** → **"Debian"** → **"Debian Bookworm (64-bit)"**

4. **Choose Storage**:

   - Click "Choose Storage"
   - Select your microSD card
   - ⚠️ **WARNING**: This will erase everything!

5. **Configure** (Click gear icon ⚙️):

   - ✅ **Enable SSH**: Checked
   - **Username**: `pi`
   - **Password**: `raspberry` (or your choice)
   - **WiFi** (optional): Enter credentials if using WiFi
   - Click "Save"

6. **Write**:

   - Click "Write"
   - Wait for completion (5-10 minutes)
   - Eject SD card safely

7. **Boot Pi**:
   - Insert SD card into Pi
   - Connect power
   - Wait for boot (30-60 seconds)

## Step 2: Find Pi IP

```bash
# Option 1: Check router admin panel
# Option 2: Scan network
nmap -sn 192.168.2.0/24 | grep -B 2 "Raspberry Pi"
# Option 3: mDNS
ping raspberrypi.local
```

## Step 3: Run Automated Setup

```bash
cd ~/WORKSPACE/raolivei/pi-fleet
./scripts/setup/setup-eldertree.sh
```

Follow prompts:

- Enter Pi IP address
- Enter SSH username (default: `pi`)
- Enter SSH password
- Enter sudo password (same as SSH password)

The script will:

1. ✅ Configure system (Ansible)
2. ✅ Install k3s (Terraform)
3. ✅ Bootstrap FluxCD (optional)

## Step 4: Verify

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
kubectl get pods -A
```

## Step 5: Restore Vault Secrets (if needed)

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Wait for Vault
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault --timeout=300s

# Unseal Vault
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && vault operator unseal <KEY1>"
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && vault operator unseal <KEY2>"
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && vault operator unseal <KEY3>"

# Restore secrets from backup
./scripts/restore-vault-secrets.sh <backup-file>
```

## Manual Steps (if automated script fails)

### 3.1: System Setup (Ansible)

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible

# Edit inventory/hosts.yml - set ansible_host to Pi IP

ansible-playbook playbooks/setup-system.yml --ask-pass --ask-become-pass
```

### 3.2: Install k3s (Terraform)

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/terraform

# Edit terraform.tfvars:
# - pi_host: "192.168.2.86" (or node-0.eldertree.local if DNS configured)
# - pi_user: "raolivei"
# - pi_password: "your-password-here" (DO NOT commit this file to git)

terraform init
terraform apply
```

### 3.3: Bootstrap FluxCD

```bash
export KUBECONFIG=~/.kube/config-eldertree

flux bootstrap github \
  --owner=raolivei \
  --repository=raolivei \
  --branch=main \
  --path=clusters/eldertree \
  --personal
```

## Troubleshooting

### Can't SSH to Pi

- Check Pi is powered on and booted
- Check network connectivity: `ping <PI_IP>`
- Check SSH service: `sudo systemctl status ssh` (on Pi console)

### Ansible fails

```bash
# Test connection
ansible all -m ping

# Use verbose output
ansible-playbook playbooks/setup-system.yml -vvv
```

### Terraform fails

```bash
# Check state
terraform show

# Re-apply
terraform apply -refresh=true
```

### k3s not ready

```bash
# Check k3s service (on Pi)
sudo systemctl status k3s
sudo journalctl -u k3s -f

# Restart if needed
sudo systemctl restart k3s
```

## What Gets Preserved

✅ **Preserved**:

- Vault secrets (if backed up)
- Application data (on USB backup drive)
- Kubernetes manifests (in Git)
- Helm charts (in Git)

❌ **Rebuilt**:

- OS and system packages
- k3s cluster (fresh install)
- System users and permissions
- Network configuration

## Full Documentation

See [OS_REINSTALLATION_GUIDE.md](./OS_REINSTALLATION_GUIDE.md) for complete details.
