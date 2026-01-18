# Password Management for pi-fleet

To improve security, hardcoded passwords have been removed from scripts and documentation. Instead, you should use environment variables or SSH keys.

## Recommended: SSH Key-Based Authentication

SSH keys are the most secure way to authenticate. Once you have SSH keys set up, most scripts and Ansible playbooks will work without needing a password.

To set up SSH keys on a new node:

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook -i inventory/hosts.yml playbooks/setup-ssh-keys.yml --limit <node-name>
```

## Environment Variable: `PI_PASSWORD`

For tasks that still require a password (like `sshpass` in some recovery scripts or first-time Ansible runs), use the `PI_PASSWORD` environment variable.

### 1. Set the variable in your current session:

```bash
export PI_PASSWORD='your_secure_password'
```

### 2. (Optional) Add it to your shell profile:

If you want it to persist across sessions, add it to your `~/.zshrc` or `~/.bash_profile`:

```bash
echo "export PI_PASSWORD='your_secure_password'" >> ~/.zshrc
source ~/.zshrc
```

**Note:** Be careful with this as it stores the password in plaintext in your profile file. A more secure way is to use a password manager's CLI to populate this variable.

## Using with Ansible

Most playbooks now look for `PI_PASSWORD` if a vault password isn't provided:

```bash
# Set the password first
export PI_PASSWORD='your_secure_password'

# Run the playbook
ansible-playbook -i inventory/hosts.yml playbooks/setup-system.yml --limit node-1
```

## Security Best Practices

1.  **Never** commit plaintext passwords to the repository.
2.  Use **Ansible Vault** for sensitive variables in playbooks.
3.  Prefer **SSH keys** over passwords whenever possible.
4.  Change default passwords immediately after a fresh install.








