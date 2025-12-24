# Restore SSH Configuration from Backup

## Quick Restore

On node-1 (where you have physical access):

```bash
# List available backups
sudo ls -lt /etc/ssh/sshd_config* | head -5

# Restore the most recent backup (usually the one with .backup extension)
sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config

# Or if there are timestamped backups, use the most recent one:
sudo cp /etc/ssh/sshd_config.*.backup /etc/ssh/sshd_config 2>/dev/null || \
sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config

# Test the config
sudo sshd -t

# If test passes, restart SSH
sudo systemctl restart ssh

# Verify it's working
sudo systemctl status ssh
```

## If No Backup Exists

If there's no backup, restore to default Debian/Ubuntu SSH config:

```bash
# Backup current broken config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.broken

# Restore from package default (if available)
sudo cp /etc/ssh/sshd_config.dpkg-old /etc/ssh/sshd_config 2>/dev/null || \
sudo apt-get install --reinstall openssh-server

# Test and restart
sudo sshd -t
sudo systemctl restart ssh
```

## After Restore

Once SSH is working again, you can SSH to node-0 and restore it there too:

```bash
ssh raolivei@node-0
# Run the same restore commands
```

