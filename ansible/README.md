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
│   └── configure-user.yml   # User configuration playbook
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

## Running Playbooks

### Basic Usage

```bash
cd ansible
ansible-playbook playbooks/configure-user.yml
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
