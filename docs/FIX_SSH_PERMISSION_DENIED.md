# Fix SSH Permission Denied on node-0

## Problem

SSH connection fails with:
```
Permission denied, please try again.
```

## Causes

1. **Password authentication disabled** in SSH config
2. **User doesn't exist** or wrong username
3. **Wrong password**
4. **SSH service not running**

## Solution: Physical Access (Recommended)

If you have physical access (keyboard/monitor):

### Step 1: Login Locally

Connect keyboard/monitor and login. Try:
- Username: `debian` (default for Debian Bookworm)
- Password: `raspberry` or what you set in Imager
- Or username: `pi` if you used Raspberry Pi OS

### Step 2: Enable Password Authentication

```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Find and change:
# PasswordAuthentication no
# To:
PasswordAuthentication yes

# Or use sed:
sudo sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
```

### Step 3: Create/Configure raolivei User

```bash
# Create user if doesn't exist
sudo useradd -m -s /bin/bash raolivei

# Set password
echo 'raolivei:Control01!' | sudo chpasswd

# Add to sudo group
sudo usermod -aG sudo raolivei

# Verify user
id raolivei
```

### Step 4: Restart SSH Service

```bash
sudo systemctl restart ssh
sudo systemctl status ssh
```

### Step 5: Test SSH

From your Mac:
```bash
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@node-0.local
```

## Solution: If You Can Access via Another User

If you can SSH as another user (e.g., `debian` or `pi`):

```bash
# SSH as that user
ssh debian@node-0.local
# or
ssh pi@node-0.local

# Then run the commands from Step 2-4 above with sudo
```

## Solution: Check Default User

Debian Bookworm fresh install might create:
- Username: `debian`
- Password: What you set in Imager (or `raspberry`)

Try:
```bash
sshpass -p 'raspberry' ssh -o StrictHostKeyChecking=no debian@node-0.local
# Or with the password you set in Imager
```

## Quick Fix Script

If you have physical access, run this script on node-0:

```bash
#!/bin/bash
# Enable password authentication
sudo sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Create/configure raolivei user
sudo useradd -m -s /bin/bash raolivei 2>/dev/null || true
echo 'raolivei:Control01!' | sudo chpasswd
sudo usermod -aG sudo raolivei

# Restart SSH
sudo systemctl restart ssh

echo "✅ SSH fixed! Try: sshpass -p 'Control01!' ssh raolivei@node-0.local"
```

## Verification

After fixing, verify:

```bash
# Check SSH config
sudo grep PasswordAuthentication /etc/ssh/sshd_config
# Should show: PasswordAuthentication yes

# Check user exists
id raolivei
# Should show user info

# Check SSH service
sudo systemctl status ssh
# Should show: active (running)

# Test SSH from Mac
sshpass -p 'Control01!' ssh -o StrictHostKeyChecking=no raolivei@node-0.local "hostname"
```

## Prevention

When setting up fresh installs:
1. **Enable SSH** in Raspberry Pi Imager settings
2. **Set username** to `raolivei` in Imager
3. **Set password** to `Control01!` in Imager
4. **Or** use the Ansible playbook to create user after first login

## Next Steps

After fixing SSH:
1. ✅ Test SSH connection
2. ✅ Run system setup playbook
3. ✅ Continue with node-0 configuration

