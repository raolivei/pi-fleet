# Eldertree Cluster Automation

All cluster configurations are fully automated via Ansible playbooks. **No manual configuration is required.**

## Automated Configurations

### 1. System Setup (`setup-system.yml`)
- User creation and configuration
- Hostname and network configuration
- Package installation
- SSH configuration
- UFW firewall basics

### 2. Terminal Monitoring (`setup-terminal-monitoring.yml`)
- Installs btop, tmux, neofetch
- **Auto-detects and configures network interface for btop** (fixes 127.0.0.1 issue)
- Creates btop wrapper script for SSH compatibility
- Configures .bashrc for auto-start

### 3. SSH Keys (`configure-ssh-keys.yml`)
- Automatically copies local SSH public key to all nodes
- Configures authorized_keys for passwordless SSH
- Sets correct permissions

### 4. WireGuard VPN (`configure-wireguard.yml`)
- **Auto-detects primary network interface** (wlan0/eth0)
- Updates WireGuard config with correct interface
- Configures UFW firewall rules for VPN network
- Restarts WireGuard service automatically

### 5. Kubernetes WireGuard Install (`configmap.yaml`)
- WireGuard install script auto-detects network interface
- No hardcoded interfaces (eth0/wlan0)
- Works on any Raspberry Pi configuration

## Running Automation

### Full Setup (All Playbooks)
```bash
cd pi-fleet/ansible
ansible-playbook playbooks/setup-eldertree.yml
```

### Individual Playbooks
```bash
# Terminal monitoring only
ansible-playbook playbooks/setup-terminal-monitoring.yml

# WireGuard configuration only
ansible-playbook playbooks/configure-wireguard.yml

# SSH keys only
ansible-playbook playbooks/configure-ssh-keys.yml
```

## What Gets Automated

✅ **btop network interface** - Auto-detected and configured  
✅ **WireGuard network interface** - Auto-detected (wlan0/eth0)  
✅ **UFW firewall rules** - VPN network and port rules  
✅ **SSH keys** - Automatically copied from local machine  
✅ **WireGuard service** - Restarted after config changes  

## No Manual Steps Required

All configurations that were previously done manually are now automated:
- ❌ ~~Manually edit `/etc/wireguard/wg0.conf`~~ → ✅ Ansible playbook
- ❌ ~~Manually configure btop `net_iface`~~ → ✅ Auto-detected in playbook
- ❌ ~~Manually add UFW rules~~ → ✅ Ansible ufw module
- ❌ ~~Manually copy SSH keys~~ → ✅ Ansible authorized_key module

## Idempotency

All playbooks are **idempotent** - safe to run multiple times. They will:
- Only make changes if needed
- Skip steps that are already configured correctly
- Not break existing configurations

## Network Interface Detection

Both btop and WireGuard playbooks automatically detect the primary network interface:
1. Checks default route: `ip route | grep default | awk '{print $5}'`
2. Falls back to `wlan0` if detection fails (common on Raspberry Pi)
3. Updates all configurations accordingly

This ensures the automation works on any Raspberry Pi regardless of whether it uses WiFi (wlan0) or Ethernet (eth0).
