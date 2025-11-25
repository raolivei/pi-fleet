# Ansible Configuration for Raspberry Pi Fleet

This directory contains Ansible playbooks and inventory for managing Raspberry Pi nodes in the eldertree cluster.

## Prerequisites

1. **Install Ansible**:

   ```bash
   # macOS
   brew install ansible

   # Linux
   sudo apt-get install ansible
   # or
   pip3 install ansible
   ```

2. **SSH Access**: Ensure you can SSH into the Raspberry Pi nodes. You can use:
   - SSH keys (recommended)
   - Password authentication (configured in inventory)

## Directory Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── inventory/
│   └── hosts.yml            # Inventory file with host definitions
├── playbooks/
│   ├── configure-user.yml              # User configuration playbook (legacy)
│   ├── setup-system.yml                # Complete system setup playbook
│   ├── install-k3s.yml                 # k3s cluster installation playbook
│   ├── bootstrap-flux.yml              # FluxCD GitOps bootstrap playbook
│   ├── setup-eldertree.yml             # Master playbook (orchestrates all steps)
│   ├── setup-terminal-monitoring.yml   # Terminal monitoring tools setup
│   ├── configure-dns.yml               # DNS configuration (/etc/hosts)
│   └── manage-secrets.yml              # Secret management in Vault
└── README.md                # This file
```

## Inventory

The inventory file (`inventory/hosts.yml`) defines the Raspberry Pi hosts:

- **eldertree**: Main cluster node (192.168.2.83)

### Updating Inventory

To add new hosts, edit `inventory/hosts.yml`:

```yaml
raspberry_pi:
  hosts:
    eldertree:
      ansible_host: 192.168.2.83
      ansible_user: pi
    new-host:
      ansible_host: 192.168.2.84
      ansible_user: pi
```

## Playbooks

### Setup System (`playbooks/setup-system.yml`) - **Recommended for Fresh Install**

Complete system setup playbook that configures:

- **User Management**: Creates `raolivei` user (password set via Ansible Vault)
- **Hostname**: Sets hostname to `eldertree`
- **Network**: Configures static IP (optional, defaults to DHCP)
- **Bluetooth**: Enables and starts Bluetooth service
- **Backup Mount**: Configures `/mnt/backup` with `nofail` option
- **SSH**: Configures SSH service
- **System Packages**: Installs essential packages (curl, git, bluez, etc.)
- **System Optimization**: Configures cgroups, timezone, NTP

**Usage**:

```bash
cd ansible
ansible-playbook playbooks/setup-system.yml --ask-pass --ask-become-pass
```

**To target specific host**:

```bash
ansible-playbook playbooks/setup-system.yml --limit eldertree --ask-pass --ask-become-pass
```

**Dry run (check mode)**:

```bash
ansible-playbook playbooks/setup-system.yml --check
```

**Variables** (can be overridden):

```yaml
hostname: eldertree
static_ip: "192.168.2.83" # Set to null/empty for DHCP
backup_device: "/dev/sdb1"
backup_mount: "/mnt/backup"
```

### Install k3s (`playbooks/install-k3s.yml`)

Install k3s lightweight Kubernetes cluster on Raspberry Pi. This playbook handles the complete k3s installation including system prerequisites, cgroup configuration, and kubeconfig retrieval.

**Features**:

- Checks if k3s is already installed (idempotent)
- Configures cgroups for container support (Raspberry Pi requirement)
- Installs k3s control plane with cluster-init mode
- Installs k9s CLI tool (optional)
- Retrieves and configures kubeconfig locally
- Saves node token for worker node joins

**Usage**:

```bash
cd ansible
ansible-playbook playbooks/install-k3s.yml --ask-pass --ask-become-pass
```

**Variables** (can be overridden):

```yaml
k3s_version: "" # Empty for latest, or specify like "v1.28.5+k3s1"
k3s_token: "" # Auto-generated if empty
k3s_hostname: "eldertree" # Hostname for TLS SAN
kubeconfig_path: "~/.kube/config-eldertree" # Local path to save kubeconfig
k3s_install_k9s: true # Install k9s CLI tool
```

**Example with custom variables**:

```bash
ansible-playbook playbooks/install-k3s.yml \
  --ask-pass --ask-become-pass \
  -e k3s_version="v1.28.5+k3s1" \
  -e k3s_hostname="my-cluster"
```

**Note**: This playbook will reboot the Pi if cgroup configuration is updated. The playbook will wait for the Pi to come back online automatically.

### Bootstrap FluxCD (`playbooks/bootstrap-flux.yml`)

Bootstrap FluxCD GitOps on the eldertree cluster. This playbook is idempotent and will skip bootstrap if FluxCD is already installed.

**Features**:

- Checks if FluxCD is already bootstrapped (idempotent)
- Verifies kubeconfig exists before proceeding
- Installs Flux CLI locally if not present
- Bootstraps FluxCD with GitHub repository sync
- Verifies installation after bootstrap

**Usage**:

```bash
cd ansible
ansible-playbook playbooks/bootstrap-flux.yml \
  -e bootstrap_flux=true \
  -e kubeconfig_path=~/.kube/config-eldertree
```

**Variables** (can be overridden):

```yaml
bootstrap_flux: true # Enable/disable bootstrap
kubeconfig_path: "~/.kube/config-eldertree" # Path to kubeconfig
flux_github_owner: "raolivei" # GitHub owner
flux_github_repo: "raolivei" # GitHub repository
flux_github_branch: "main" # Git branch
flux_github_path: "clusters/eldertree" # Path in repository
flux_github_personal: true # Use personal GitHub token
```

**Example with custom variables**:

```bash
ansible-playbook playbooks/bootstrap-flux.yml \
  -e bootstrap_flux=true \
  -e flux_github_owner=myorg \
  -e flux_github_repo=myrepo
```

**Note**: This playbook runs on `localhost` and requires Flux CLI to be installed locally. The kubeconfig must exist before running this playbook (k3s must be installed first).

### Setup Eldertree (`playbooks/setup-eldertree.yml`)

Master playbook that orchestrates the complete eldertree cluster setup. This playbook includes system configuration, k3s installation, and optional FluxCD bootstrap.

**Usage**:

```bash
cd ansible
ansible-playbook playbooks/setup-eldertree.yml \
  -e bootstrap_flux=true
```

**Variables**:

All variables from `setup-system.yml` plus:

- `bootstrap_flux`: Boolean to enable/disable FluxCD bootstrap (default: false)
- `kubeconfig_path`: Path to kubeconfig file (default: `~/.kube/config-eldertree`)

**Workflow**:

1. Runs `setup-system.yml` for system configuration
2. Runs `install-k3s.yml` for k3s cluster installation
3. Optionally runs `bootstrap-flux.yml` if `bootstrap_flux=true`

**Recommended**: Use the `setup-eldertree.sh` script instead, which properly orchestrates all steps.

### Setup Terminal Monitoring (`playbooks/setup-terminal-monitoring.yml`)

Installs and configures terminal-based monitoring tools that display system information on login.

**Features**:

- **btop**: Modern, colorful terminal-based system monitor (replacement for htop)
- **neofetch**: System information with ASCII art
- **tmux**: Terminal multiplexer for persistent sessions
- **Login Banner**: Custom system info script that displays on SSH/login
- **Raspberry Pi Metrics**: CPU temperature, voltage, throttling status

**What it does**:

- Installs `btop`, `neofetch`, and `tmux` packages
- Creates `~/.system-info.sh` script with system metrics
- Configures `.bashrc` to display system info on login (interactive shells only)
- Shows: hostname, uptime, CPU temp, load, memory, disk, IP, Kubernetes status

**Usage**:

```bash
cd ansible
ansible-playbook playbooks/setup-terminal-monitoring.yml --ask-pass --ask-become-pass
```

**To target specific host**:

```bash
ansible-playbook playbooks/setup-terminal-monitoring.yml --limit eldertree --ask-pass --ask-become-pass
```

**After installation**:

- System info will automatically display when you SSH/login
- Run `btop` for interactive system monitoring
- Run `neofetch` for system info with ASCII art
- Run `htop` for classic process monitor (already installed)

**Variables**:

Uses the same `target_user` variable as other playbooks (defaults to `raolivei`).

### Configure DNS (`playbooks/configure-dns.yml`)

Configure DNS for eldertree cluster services. This playbook manages local DNS configuration via `/etc/hosts` entries.

**Features**:

- Adds DNS entries for cluster services (\*.eldertree.local)
- Supports Pi-hole DNS (recommended) or /etc/hosts fallback
- Idempotent (won't duplicate entries)

**Usage**:

```bash
cd ansible
ansible-playbook playbooks/configure-dns.yml \
  -e configure_hosts_file=true \
  -e eldertree_ip=192.168.2.83
```

**Variables**:

- `eldertree_ip`: Cluster IP address (default: 192.168.2.83)
- `configure_hosts_file`: Enable /etc/hosts configuration (default: false)
- `services`: List of services to configure (default: predefined list)

**Note**: For better automation, use the convenience script: `./scripts/setup/setup-dns.sh`

### Manage Secrets (`playbooks/manage-secrets.yml`)

Manage secrets in Vault. This playbook provides a declarative way to store secrets in Vault.

**Features**:

- Store multiple secrets in a single run
- Idempotent secret management
- Works with External Secrets Operator

**Usage**:

```bash
cd ansible
ansible-playbook playbooks/manage-secrets.yml \
  -e 'secrets=[
    {path: "secret/terraform/cloudflare-api-token", data: {api-token: "YOUR_TOKEN"}},
    {path: "secret/external-dns/cloudflare-api-token", data: {api-token: "YOUR_TOKEN"}}
  ]'
```

**Variables**:

- `kubeconfig_path`: Path to kubeconfig (default: ~/.kube/config-eldertree)
- `vault_namespace`: Vault namespace (default: vault)
- `secrets`: List of secrets to store (see example above)

**Note**: For convenience, use the wrapper script: `./scripts/secrets/store-cloudflare-token.sh YOUR_TOKEN`

### Configure User (`playbooks/configure-user.yml`)

Legacy playbook - use `setup-system.yml` instead for fresh installs.

Creates and configures the `raolivei` user with:

- Admin privileges (sudo access)
- Password: Set via Ansible Vault (see Password Management section)
- Passwordless sudo
- Proper home directory setup

**Usage**:

```bash
cd ansible
ansible-playbook playbooks/configure-user.yml
```

**To target specific host**:

```bash
ansible-playbook playbooks/configure-user.yml --limit eldertree
```

**Dry run (check mode)**:

```bash
ansible-playbook playbooks/configure-user.yml --check
```

## Password Management

### ⚠️ Security: Passwords Must Not Be Committed to Git

**NEVER commit passwords to git repositories.** All passwords must be managed via Ansible Vault or environment variables.

### Setting the Password

The password for `raolivei` is hashed using SHA-512 at runtime using Ansible's `password_hash` filter. The password can be set using one of these methods:

1. **Option 1: Use Ansible Vault** (recommended):

   ```bash
   # Create encrypted variables file
   ansible-vault create group_vars/raspberry_pi/vault.yml
   ```

   Add to vault file:

   ```yaml
   vault_target_password: "YourSecurePassword123!"
   ```

   The playbook automatically uses `vault_target_password` if available.

   Run playbook with vault:

   ```bash
   ansible-playbook playbooks/setup-system.yml --ask-vault-pass
   ```

2. **Option 2: Use Environment Variable**:

   ```bash
   export env_target_password="YourSecurePassword123!"
   ansible-playbook playbooks/setup-system.yml
   ```

3. **Option 3: Use Ansible Vault Encrypt String** (for inventory):

   ```bash
   ansible-vault encrypt_string 'YourSecurePassword123!' --name 'ansible_password'
   ```

   Add the encrypted string to `inventory/hosts.yml`:

   ```yaml
   ansible_password: !vault |
     $ANSIBLE_VAULT;1.1;AES256
     ...
   ```

   Update playbook to use vault variable:

   ```yaml
   vars:
     target_password: "{{ vault_target_password }}"
   ```

   Run with vault password:

   ```bash
   ansible-playbook playbooks/configure-user.yml --ask-vault-pass
   ```

4. **Option 3: Use command-line variable**:
   ```bash
   ansible-playbook playbooks/configure-user.yml \
     -e "target_password=NewPassword123!"
   ```

### Generating Password Hash Manually

If you need to generate a password hash manually:

```bash
# Using Python
python3 -c "import crypt; print(crypt.crypt('YourPassword', crypt.mksalt(crypt.METHOD_SHA512)))"

# Using Ansible
ansible localhost -m debug -a "msg={{ 'YourPassword' | password_hash('sha512') }}"
```

## Complete Setup Workflow

For a complete eldertree cluster setup, use the automated script:

```bash
cd pi-fleet
./scripts/setup/setup-eldertree.sh
```

This script orchestrates:

1. **Ansible** - System configuration (`setup-system.yml`)
2. **Ansible** - k3s cluster installation (`install-k3s.yml`)
3. **Ansible** - FluxCD bootstrap (`bootstrap-flux.yml`)

The script is idempotent and can be run multiple times safely.

### Manual Step-by-Step Setup

If you prefer manual control:

```bash
# 1. System configuration
cd ansible
ansible-playbook playbooks/setup-system.yml --ask-pass --ask-become-pass

# 2. Install k3s
ansible-playbook playbooks/install-k3s.yml --ask-pass --ask-become-pass

# 3. Bootstrap FluxCD (optional)
ansible-playbook playbooks/bootstrap-flux.yml -e bootstrap_flux=true
```

## Running Playbooks

### Basic Usage

```bash
cd ansible
ansible-playbook playbooks/setup-system.yml --ask-pass --ask-become-pass
```

### Common Options

- **Check mode (dry run)**: `--check`
- **Verbose output**: `-v`, `-vv`, `-vvv`
- **Limit to specific hosts**: `--limit eldertree`
- **Ask for sudo password**: `--ask-become-pass`
- **Ask for vault password**: `--ask-vault-pass`
- **Extra variables**: `-e "var=value"`

### Examples

```bash
# Dry run to see what would change
ansible-playbook playbooks/configure-user.yml --check

# Verbose output
ansible-playbook playbooks/configure-user.yml -vv

# Run only on eldertree
ansible-playbook playbooks/configure-user.yml --limit eldertree

# Run with custom password
ansible-playbook playbooks/configure-user.yml \
  -e "target_password=NewPassword123!"
```

## SSH Configuration

### Using SSH Keys (Recommended)

1. Generate SSH key if you don't have one:

   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

2. Copy public key to Raspberry Pi:

   ```bash
   ssh-copy-id pi@192.168.2.83
   ```

3. Test connection:
   ```bash
   ssh pi@192.168.2.83
   ```

### Using Password Authentication

If using password authentication, you can:

1. **Set in inventory** (less secure):

   ```yaml
   ansible_password: "your-password"
   ```

2. **Use --ask-pass flag**:
   ```bash
   ansible-playbook playbooks/configure-user.yml --ask-pass
   ```

## Troubleshooting

### Connection Issues

- **Host key checking**: Disabled in `ansible.cfg` for convenience. Re-enable for production.
- **SSH timeout**: Increase timeout in `ansible.cfg`:
  ```ini
  [ssh_connection]
  timeout = 30
  ```

### Permission Issues

- Ensure the connecting user (`pi`) has sudo access
- Use `--ask-become-pass` if sudo requires password

### Testing Connection

Test connectivity to hosts:

```bash
ansible all -m ping
```

Test with specific user:

```bash
ansible all -m ping -u pi
```

### FluxCD Bootstrap Issues

- **Kubeconfig not found**: Ensure Ansible playbook `install-k3s.yml` has been run to install k3s and generate kubeconfig
- **Flux CLI not found**: Install with `brew install fluxcd/tap/flux`
- **GitHub token**: Ensure GitHub token is configured for Flux bootstrap (check `~/.config/gh/` or set `GITHUB_TOKEN`)
- **Already bootstrapped**: Playbook will skip bootstrap if FluxCD is already installed (idempotent)

### k3s Installation Issues

- **Ansible fails**: Check SSH connectivity and credentials
- **k3s not ready**: Check k3s service on Pi: `ssh pi@<IP> 'sudo systemctl status k3s'`
- **Cgroup errors**: The playbook will automatically configure cgroups and reboot if needed
- **Kubeconfig missing**: Re-run `install-k3s.yml` to regenerate kubeconfig
- **Reboot required**: If cgroups are updated, the Pi will reboot automatically. The playbook waits for it to come back online.

## Security Considerations

1. **Password Storage**: Consider using Ansible Vault for sensitive passwords
2. **SSH Keys**: Prefer SSH key authentication over passwords
3. **Host Key Checking**: Re-enable in production environments
4. **Sudo Access**: The playbook configures passwordless sudo. Consider requiring passwords for production:
   ```yaml
   line: "{{ target_user }} ALL=(ALL) ALL"
   ```

## Adding New Playbooks

To add a new playbook:

1. Create file in `playbooks/` directory
2. Follow Ansible best practices
3. Update this README with usage instructions
4. Test with `--check` first

Example structure:

```yaml
---
- name: Description of playbook
  hosts: raspberry_pi
  become: yes
  tasks:
    - name: Task description
      # ... task configuration
```
