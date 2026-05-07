# Pi Fleet - AI Assistant Context

## Quick Reference

- **Project Type**: K3s cluster management on Raspberry Pi
- **Cluster Name**: `eldertree` (HA control plane)
- **Nodes**: `node-1`, `node-2`, `node-3` (all HA control-plane servers)
- **Control Plane VIP**: 192.168.2.100 (kube-vip)
- **Management Tools**: Ansible (system config), Terraform (infrastructure), FluxCD (GitOps)
- **Hardware**: Raspberry Pi 5 (8GB, ARM64), Debian 12 Bookworm, NVMe SSD boot

## Critical Rules

### Git Workflow
- **NEVER commit directly to main** - Always use feature branches and PRs
- **Branch prefixes**: `feat/`, `fix/`, `docs/`, `chore/`, `infra/`
- **Commit format**: `<type>: <description>` (e.g., `feat: add monitoring`, `fix: dns-config`)
- **Workflow**: `git checkout main → git pull → git checkout -b <type>/<name>`

### Versioning & Changes
- **Git tag versions must match Docker image tags** - Ensure consistency across releases
- **ANY Docker image changes must update CHANGELOG.md** - Dockerfiles, base images, tags in manifests
- **Follow Keep a Changelog format** - Version headers, categories (Added, Changed, Fixed, etc.)

### Ansible Safety
- **Always use variables from `group_vars/all.yml`** - NEVER hardcode IPs, hostnames, network settings
- **Idempotent playbooks** - Safe to run multiple times
- **Minimize reboots** - Use `netplan apply` instead of reboot for network changes
- **ALWAYS use sshpass** - Never plain `ssh` commands: `sshpass -p 'PASSWORD' ssh ...`

### Network Configuration Safety
- **DHCP by default** - Static IP is opt-in only (requires `-e "configure_static_ip=true"`)
- **Preserve wlan0 DHCP** - When configuring static IP on eth0, keep wlan0 as DHCP
- **Isolated switch setup** - Use separate subnet (10.0.0.0/24) without gateway/DNS
- **Router DHCP reservations preferred** - Avoids network breakage from static config

### NVMe Boot Requirements (Raspberry Pi 5)
- **ESP flag required** - Boot partition MUST have ESP flag: `parted /dev/nvme0n1 set 1 esp on`
- **Use rsync, NOT dd** - For cloning root partition (avoids filesystem size issues)
- **Update fstab PARTUUIDs** - After cloning, update to NVMe PARTUUIDs
- **cmdline.txt update** - Must point to `root=/dev/nvme0n1p2`
- **Root lock prevention** - Unlock root, set password, disable PAM faillock before boot device switch

## When to Read What

### Getting Started
- **New to project?** → This file + [README.md](README.md)
- **Ansible overview?** → [ansible/README.md](ansible/README.md)
- **Git workflow details?** → [CONTRIBUTING.md](CONTRIBUTING.md)

### Cluster Setup
- **Adding new node?** → [docs/ADD_WORKER_NODE.md](docs/ADD_WORKER_NODE.md)
- **HA control plane?** → [docs/HA_SETUP.md](docs/HA_SETUP.md)
- **NVMe boot setup?** → [docs/NVME_BOOT_SETUP.md](docs/NVME_BOOT_SETUP.md)
- **Fresh OS installation?** → [docs/FRESH_INSTALL_MIGRATION.md](docs/FRESH_INSTALL_MIGRATION.md)

### Network & DNS
- **Network architecture?** → [NETWORK.md](NETWORK.md)
- **DNS troubleshooting?** → [docs/DNS_TROUBLESHOOTING.md](docs/DNS_TROUBLESHOOTING.md)
- **Cloudflare setup?** → [docs/CLOUDFLARE_DOMAINS.md](docs/CLOUDFLARE_DOMAINS.md)
- **Tailscale VPN?** → [docs/TAILSCALE.md](docs/TAILSCALE.md)

### Secrets & Security
- **Vault overview?** → [VAULT.md](VAULT.md)
- **Vault quick reference?** → [docs/VAULT_QUICK_REFERENCE.md](docs/VAULT_QUICK_REFERENCE.md)
- **Vault recovery?** → [docs/VAULT_RECOVERY.md](docs/VAULT_RECOVERY.md)
- **Password management?** → [docs/PASSWORD_MANAGEMENT.md](docs/PASSWORD_MANAGEMENT.md)

### Troubleshooting
- **ALWAYS check runbook first** → https://docs.eldertree.xyz (public) or https://docs.eldertree.local (internal)
- **Node issues?** → [docs/NODE_TROUBLESHOOTING.md](docs/NODE_TROUBLESHOOTING.md)
- **Boot failures?** → [docs/NVME_BOOT_TROUBLESHOOTING.md](docs/NVME_BOOT_TROUBLESHOOTING.md)
- **Root account locked?** → [docs/RECOVER_LOCKED_ROOT.md](docs/RECOVER_LOCKED_ROOT.md)
- **Emergency mode?** → [docs/EMERGENCY_MODE_RECOVERY.md](docs/EMERGENCY_MODE_RECOVERY.md)
- **SSH permission denied?** → [docs/FIX_SSH_PERMISSION_DENIED.md](docs/FIX_SSH_PERMISSION_DENIED.md)
- **Network connectivity?** → [docs/RECOVER_NETWORK_CONNECTIVITY.md](docs/RECOVER_NETWORK_CONNECTIVITY.md)
- **k3s service issues?** → [docs/K3S_SERVICE_TROUBLESHOOTING.md](docs/K3S_SERVICE_TROUBLESHOOTING.md)

### Ingress & Access
- **Ingress setup?** → [docs/INGRESS.md](docs/INGRESS.md)
- **Lens connection?** → [docs/LENS_CONNECTION_GUIDE.md](docs/LENS_CONNECTION_GUIDE.md)

### Storage & Backup
- **Backup strategy?** → [docs/BACKUP_STRATEGY.md](docs/BACKUP_STRATEGY.md)
- **2TB backup drive?** → [docs/SETUP_2TB_BACKUP_DRIVE.md](docs/SETUP_2TB_BACKUP_DRIVE.md)
- **Multi-node storage?** → [docs/MULTI_NODE_STORAGE.md](docs/MULTI_NODE_STORAGE.md)

## Project Structure

```
pi-fleet/
├── ansible/              # Ansible playbooks for system configuration
│   ├── inventory/        # Host inventory (node-1, node-2, node-3)
│   ├── playbooks/        # System setup, K3s install, NVMe boot, etc.
│   └── group_vars/       # Centralized variables (network, IPs, etc.)
├── terraform/            # Infrastructure as code (Cloudflare, etc.)
├── clusters/             # FluxCD GitOps manifests
│   └── eldertree/        # Control plane cluster configs
├── helm/                 # Custom Helm charts
├── scripts/              # Utility scripts
├── docs/                 # Documentation (90+ files)
├── CLAUDE.md             # This file - AI assistant entry point
├── NETWORK.md            # Network and DNS overview
├── VAULT.md              # Secrets management overview
└── CONTRIBUTING.md       # Git workflow details
```

## Node Configuration

### Node Naming & IPs
- **node-1**: 192.168.2.101 (WiFi) / 10.0.0.1 (Gigabit)
- **node-2**: 192.168.2.102 (WiFi) / 10.0.0.2 (Gigabit)
- **node-3**: 192.168.2.103 (WiFi) / 10.0.0.3 (Gigabit)
- **kube-vip VIP**: 192.168.2.100 (HA API server access)
- **node-x**: Generic hostname on backup SD card for recovery

### Node Roles
All nodes are **identical HA control-plane servers** (not workers). Full high availability setup.

## Ansible Playbook Structure

### Master Playbooks (Orchestration)
- `setup-eldertree.yml` - Complete control plane setup
- `setup-worker-node.yml` - Complete worker node setup

### Component Playbooks (Used by Masters)
- `setup-system.yml` - System configuration (user, hostname, network, packages)
- `setup-ssh-keys.yml` - SSH key generation and distribution
- `setup-nvme-boot.yml` - NVMe boot configuration
- `install-k3s.yml` - K3s server installation
- `install-k3s-worker.yml` - K3s worker installation
- `setup-terminal-monitoring.yml` - Terminal tools (btop, etc.)

### Recovery Playbooks
- `fix-root-lock.yml` - Unlock root account
- `fix-emergency-mode.yml` - Fix emergency mode and root lock

### Essential Variables (`group_vars/all.yml`)
- Network config: `network_base`, `network_gateway`, `network_dns`
- Node IPs: `node_1_ip`, `node_2_ip`, `node_3_ip`
- k3s config: `k3s_server_url`, `k3s_server_ip`

## Common Tasks

### Adding New Worker Node
1. Flash OS using Raspberry Pi Imager (Debian Bookworm 64-bit)
2. Boot Pi and find IP address
3. Update `ansible/inventory/hosts.yml` with sequential IP
4. Run setup:
   ```bash
   cd ansible
   ansible-playbook -i inventory/hosts.yml \
     playbooks/setup-worker-node.yml \
     --limit node-X
   ```
5. Verify: `kubectl get nodes`

### Setting Up NVMe Boot
1. Verify NVMe detected: `lsblk | grep nvme`
2. Run setup:
   ```bash
   cd ansible
   ansible-playbook -i inventory/hosts.yml \
     playbooks/setup-nvme-boot.yml \
     --limit node-X \
     -e "setup_nvme_boot=true" \
     -e "target_password=password"
   ```
3. Reboot: `sudo reboot`
4. Verify: `df -h /` should show `/dev/nvme0n1p2`

### Recovering from Root Lock
1. If booted from SD card: Run `fix-root-lock.yml`
2. If in emergency mode: Run `fix-emergency-mode.yml`
3. Or manually:
   ```bash
   sudo passwd -u root
   sudo passwd root  # Set password
   sudo faillock --user root --reset
   ```

### Updating FluxCD Manifests
1. Edit manifests in `clusters/<cluster-name>/`
2. Commit and push to git
3. FluxCD automatically syncs
4. Monitor: `flux get kustomizations`

### Kubernetes Access
```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
kubectl get pods -A
```

## Essential Packages

Always install via `setup-system.yml`:
- `sshpass` - Password-based SSH automation
- `btop` - Terminal monitoring (preferred over htop)
- `curl`, `wget`, `git`, `vim`, `htop`, `tmux`
- `rsync` - File copying (not dd)
- `iptables`, `ufw` - Firewall
- `openssh-server` - SSH access

## Troubleshooting Runbook

**IMPORTANT: Always check the runbook first when encountering issues.**

### Runbook Locations
- **Public**: https://docs.eldertree.xyz
- **Local**: https://docs.eldertree.local (within cluster network)
- **Repository**: https://github.com/raolivei/eldertree-docs

### How to Use
1. **Copy exact error message** from logs or terminal
2. **Search runbook** using VitePress search (press `/` or `Ctrl+K`)
3. **Review matching issues** - Multiple issues may match same symptom
4. **Follow resolution steps** in matched issue file
5. **Verify fix** using provided verification commands

### Common Issue Categories
- **DNS**: CoreDNS failures, Pi-hole issues, DNS timeouts
- **Cloudflare**: Tunnel DNS timeout, HTTP 530, external access
- **Node**: Node unreachable, dual IP, cluster membership
- **Boot**: Boot failures, NVMe boot, emergency mode
- **Network**: Network recovery, connectivity issues
- **Storage**: Vault recovery, Longhorn issues
- **SSH**: Permission denied, locked accounts

### When No Match Found
If runbook doesn't have matching issue:
1. Troubleshoot using standard Kubernetes debugging
2. Document new issue in runbook for future reference
3. Add exact error messages for searchability

## Secrets Management (Vault)

- Secrets stored in HashiCorp Vault (see [VAULT.md](VAULT.md))
- Use `scripts/sync-vault-to-k8s.sh` to sync secrets to Kubernetes
- Never commit secrets to git
- External Secrets Operator automatically syncs from Vault

## Ingress & SSL

- Traefik as Ingress Controller
- Cert-Manager for SSL certificates
- ExternalDNS for DNS records
- See [docs/INGRESS.md](docs/INGRESS.md)

## Key Principles

1. **GitOps** - Infrastructure and apps defined in git
2. **Infrastructure as Code** - Ansible for system config, Terraform for provisioning
3. **Self-hosted** - Runs on Raspberry Pi hardware
4. **FluxCD** - Automatic sync from git
5. **Secrets in Vault** - Never in git
6. **Safety First** - DHCP by default, opt-in for risky changes
7. **Idempotency** - All playbooks safe to run multiple times
8. **Automation** - SSH keys, package installs, system config automated
9. **Documentation** - Searchable runbook for all issues

## Search Tips

1. **Copy exact error messages** from kubectl, systemctl, or logs
2. **Search runbook first** at https://docs.eldertree.xyz
3. **Check docs/ directory** - 90+ troubleshooting and setup guides
4. **Grep for specific terms** in ansible/, docs/, or clusters/
5. **Reference inventory** in `ansible/inventory/hosts.yml` for current node config

## External References

- **Runbook**: https://docs.eldertree.xyz - Comprehensive troubleshooting guide
- **Runbook GitHub**: https://github.com/raolivei/eldertree-docs
- **Workspace Config**: `../workspace-config/` - Port assignments, conventions

---

**Last Updated**: 2026-05-07  
**Cluster Status**: HA control plane (3 nodes)  
**For Issues**: Check https://docs.eldertree.xyz first
