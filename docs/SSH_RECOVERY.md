<!-- MIGRATED TO RUNBOOK -->
> **📚 This document has been migrated to the Eldertree Runbook**
>
> For the latest version, see: [SSH-002](https://docs.eldertree.xyz/runbook/issues/ssh/SSH-002)
>
> The runbook provides searchable troubleshooting guides with improved formatting.

---


# SSH Service Recovery Guide

## Problem

After running `setup-all-nodes.yml`, SSH service failed on both nodes. You cannot SSH into node-0 or node-1.

## Root Cause

The SSH configuration was modified, and the SSH service failed to restart. The `ignore_errors: true` in the playbook masked the failure, but SSH is now down.

## Solution Options

### Option 1: Physical Access (Recommended)

If you have physical access to the nodes:

1. **Connect a keyboard and monitor** to node-0 (or node-1)

2. **Login** as `raolivei` (or root if needed)

3. **Run the fix script**:
   ```bash
   sudo /path/to/fix-ssh-service.sh
   ```
   
   Or manually:
   ```bash
   # Check SSH service name
   sudo systemctl list-units --type=service | grep -E 'ssh|sshd'
   
   # Check SSH config syntax
   sudo sshd -t
   
   # If config is valid, start SSH
   sudo systemctl start ssh  # or sshd
   sudo systemctl enable ssh
   sudo systemctl status ssh
   ```

4. **If SSH config has errors**, check what was changed:
   ```bash
   sudo diff /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
   ```
   
   Or restore the backup:
   ```bash
   sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
   sudo systemctl restart ssh
   ```

### Option 2: Check SSH Config Syntax

The SSH config modification might have introduced a syntax error. Check:

```bash
# On the node (physical access)
sudo sshd -t
```

Common issues:
- Missing quotes around values
- Invalid option names
- Duplicate entries

### Option 3: Restore from Backup

Ansible should have created a backup. Check for it:

```bash
# On the node (physical access)
ls -la /etc/ssh/sshd_config*
sudo cp /etc/ssh/sshd_config.*.backup /etc/ssh/sshd_config
sudo systemctl restart ssh
```

### Option 4: Minimal SSH Config

If all else fails, restore a minimal working SSH config:

```bash
# On the node (physical access)
sudo tee /etc/ssh/sshd_config > /dev/null <<EOF
Port 22
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
EOF

sudo systemctl restart ssh
```

## Prevention

The playbook should be updated to:
1. Test SSH config syntax before applying changes
2. Not restart SSH if we're connected via SSH (or use a different approach)
3. Create a backup before modifying SSH config
4. Verify SSH is still accessible after changes

## Next Steps After Recovery

Once SSH is working again:

1. **Verify SSH works**:
   ```bash
   ssh raolivei@node-0
   ssh raolivei@node-1
   ```

2. **Review what went wrong**:
   ```bash
   # Check SSH config
   sudo sshd -T | grep -E "SendEnv|PermitRootLogin|PasswordAuthentication"
   ```

3. **Update the playbook** to prevent this issue in the future

