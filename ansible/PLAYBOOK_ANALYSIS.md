# Ansible Playbook Analysis and Best Practices

## Overview

This document analyzes the Ansible playbook structure, identifies redundancies, and provides recommendations for improvement.

## Current Playbook Count

**Total playbooks**: 30

## Master Playbooks

### Existing Master Playbooks

1. **`setup-new-node.yml`** ⭐ **NEW - RECOMMENDED**

   - Complete setup for new worker nodes
   - Includes: system, NVMe, network, k3s, SSH keys, monitoring, Longhorn
   - **Use this for new node setup**

2. **`setup-worker-node.yml`**

   - Older master playbook
   - Missing: NVMe setup, gigabit network configuration
   - **Status**: Deprecated in favor of `setup-new-node.yml`

3. **`setup-all-nodes.yml`**

   - For configuring all nodes at once
   - Includes: system, monitoring, SSH keys
   - **Status**: Useful for bulk operations

4. **`configure-fresh-nodes.yml`**
   - Basic fresh installation configuration
   - Includes: hostname, PoE HAT, NVMe detection
   - **Status**: Useful for initial SD card setup

## Playbook Categories

### Core Setup Playbooks (Required)

- `setup-system.yml` - Base system configuration
- `setup-nvme-boot.yml` - NVMe boot setup with emergency mode prevention
- `install-k3s.yml` - Control plane installation
- `install-k3s-worker.yml` - Worker node installation
- `configure-k3s-gigabit.yml` - k3s network configuration

### Supporting Playbooks (Required)

- `setup-ssh-keys.yml` - SSH key management
- `setup-terminal-monitoring.yml` - Monitoring tools (btop, tmux, neofetch)
- `setup-longhorn-node.yml` - Longhorn prerequisites

### Utility Playbooks (Optional/As Needed)

- `discover-nodes.yml` - Node discovery
- `fix-nvme-boot.yml` - NVMe boot fixes
- `fix-root-lock.yml` - Root account fixes
- `fix-emergency-mode.yml` - Emergency mode recovery
- `configure-eth0-static.yml` - Static eth0 configuration
- `configure-dns.yml` - DNS configuration
- `configure-wireguard.yml` - WireGuard setup
- `bootstrap-flux.yml` - FluxCD bootstrap

### Redundant/Deprecated Playbooks

- `setup-worker-node.yml` - **DEPRECATED** - Replaced by `setup-new-node.yml`
- `configure-ssh-keys.yml` - **DEPRECATED** - Functionality merged into `setup-ssh-keys.yml`
- `configure-user.yml` - Functionality included in `setup-system.yml` (can be removed if not used separately)

## Best Practices Assessment

### ✅ Good Practices

1. **Idempotency**: Most playbooks use Ansible modules (not shell commands)
2. **Variable Management**: Using vault and environment variables for secrets
3. **Modularity**: Playbooks are focused and reusable
4. **Documentation**: Playbooks have clear descriptions

### ⚠️ Areas for Improvement

1. **Password Handling**:

   - ✅ No hardcoded passwords in playbooks
   - ⚠️ Password examples in documentation (should use placeholders)
   - ✅ Using vault and environment variables

2. **Master Playbook**:

   - ✅ Created `setup-new-node.yml` as comprehensive master playbook
   - ⚠️ Old `setup-worker-node.yml` should be deprecated

3. **Redundancy**:

   - ⚠️ Multiple playbooks for similar tasks (configure-ssh-keys vs setup-ssh-keys)
   - ⚠️ Some playbooks could be consolidated

4. **Error Handling**:
   - ✅ Most playbooks have proper error handling
   - ⚠️ Some use `failed_when: false` which might hide issues

## Recommendations

### 1. Use Master Playbook for New Nodes

**For new node setup, use:**

```bash
ansible-playbook playbooks/setup-new-node.yml \
  --limit node-X \
  -e "wlan0_ip=192.168.2.XX" \
  -e "eth0_ip=10.0.0.X" \
  -e "k3s_token=<token>" \
  --ask-pass --ask-become-pass
```

This single playbook handles:

- System configuration
- NVMe boot setup (with emergency mode prevention)
- Gigabit network configuration
- k3s worker installation
- k3s network configuration
- SSH keys
- Terminal monitoring
- Longhorn prerequisites

### 2. Consolidate Redundant Playbooks

**Action Items:**

- [x] Consolidated `configure-ssh-keys.yml` into `setup-ssh-keys.yml` (marked as deprecated)
- [x] Created `setup-new-node.yml` to replace `setup-worker-node.yml`
- [x] Converted shell/command calls to Ansible modules in `setup-new-node.yml`
- [ ] Review `configure-user.yml` - merge into `setup-system.yml` if redundant

### 3. Password Security

**Current Status:**

- ✅ No passwords in playbooks
- ✅ Using vault and environment variables
- ⚠️ Documentation has example passwords (should use placeholders)

**Action Items:**

- [x] Replace password examples in documentation with placeholders
- [ ] Add `.env.example` file with placeholders
- [ ] Document password management in README

### 4. Playbook Organization

**Suggested Structure:**

```
playbooks/
├── setup/
│   ├── setup-new-node.yml (master)
│   ├── setup-system.yml
│   ├── setup-nvme-boot.yml
│   └── setup-longhorn-node.yml
├── k3s/
│   ├── install-k3s.yml
│   ├── install-k3s-worker.yml
│   └── configure-k3s-gigabit.yml
├── network/
│   ├── configure-eth0-static.yml
│   └── configure-dns.yml
├── utilities/
│   ├── discover-nodes.yml
│   ├── setup-ssh-keys.yml
│   └── setup-terminal-monitoring.yml
└── fixes/
    ├── fix-nvme-boot.yml
    ├── fix-root-lock.yml
    └── fix-emergency-mode.yml
```

## Summary

### ✅ Strengths

- Well-structured and modular playbooks
- Good use of Ansible modules (idempotent)
- Proper variable management
- Comprehensive master playbook (`setup-new-node.yml`)

### 🔧 Improvements Completed

- ✅ Consolidated `configure-ssh-keys.yml` into `setup-ssh-keys.yml`
- ✅ Created `setup-new-node.yml` master playbook
- ✅ Converted nmcli commands to `community.general.nmcli` module
- ✅ Converted k3s token retrieval to use `slurp` module
- ✅ Improved IP verification using `setup` module instead of shell commands

### 🔧 Improvements Still Needed

- Organize playbooks into subdirectories (optional)
- Convert remaining shell commands in other playbooks (low priority)
- Review `configure-user.yml` for consolidation

### 📋 Quick Reference

**For new node setup:**

```bash
ansible-playbook playbooks/setup-new-node.yml --limit node-X \
  -e "wlan0_ip=192.168.2.XX" \
  -e "eth0_ip=10.0.0.X" \
  -e "k3s_token=<token>" \
  --ask-pass --ask-become-pass
```

**For control plane setup:**

```bash
ansible-playbook playbooks/install-k3s.yml --limit node-0
```

**For bulk node configuration:**

```bash
ansible-playbook playbooks/setup-all-nodes.yml
```
