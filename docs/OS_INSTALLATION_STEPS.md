# OS Installation Steps - Detailed Guide

This guide focuses specifically on installing the operating system on your Raspberry Pi SD card.

## Prerequisites

- Raspberry Pi 5 (or compatible)
- MicroSD card (32GB+ recommended, Class 10 or better)
- SD card reader/adapter for your Mac
- Raspberry Pi Imager installed

## Step 1: Install Raspberry Pi Imager

### macOS

```bash
# Using Homebrew (recommended)
brew install --cask raspberry-pi-imager

# Or download from:
# https://www.raspberrypi.com/software/
```

### Verify Installation

```bash
# Check if installed
which rpi-imager

# Or open from Applications
open -a "Raspberry Pi Imager"
```

## Step 2: Prepare SD Card

1. **Insert SD card** into your Mac (using adapter if needed)
2. **Check disk name**:
   ```bash
   diskutil list
   ```
   Note the disk identifier (e.g., `/dev/disk2`)

3. **⚠️ IMPORTANT**: Make sure you have backups! This will erase everything on the SD card.

## Step 3: Flash OS Using Raspberry Pi Imager

### Launch Imager

```bash
# From terminal
open -a "Raspberry Pi Imager"

# Or find it in Applications
```

### Choose Operating System

1. Click **"Choose OS"** button
2. Navigate to: **"Other general-purpose OS"** → **"Debian"** → **"Debian Bookworm (64-bit)"**

   **Why Debian Bookworm?**
   - Matches current cluster setup
   - Minimal, server-focused
   - Better performance for k3s

   **Alternative**: You can also use **"Raspberry Pi OS (64-bit)"** if preferred.

### Choose Storage

1. Click **"Choose Storage"** button
2. Select your microSD card from the list
3. **⚠️ DOUBLE-CHECK**: Make sure you selected the SD card, not your Mac's internal drive!

### Configure Settings

Click the **gear icon (⚙️)** to open settings:

#### Essential Settings

- ✅ **Enable SSH**: **MUST BE CHECKED** - Required for automation
- **Set username**: `pi` (default)
- **Set password**: `raspberry` (or choose your own - remember it!)
- **SSH public key** (optional): Add your SSH public key for passwordless login

#### Network Settings (Optional)

- **Configure wireless LAN**: 
  - Check if using WiFi
  - Enter SSID and password
  - Select country

#### Advanced Settings (Optional)

- **Set hostname**: Leave as `raspberrypi` (we'll change it later)
- **Set locale settings**:
  - Timezone: `America/Toronto` (or your timezone)
  - Keyboard layout: `us` (or your layout)
- **Enable telemetry**: Uncheck if you don't want to share data

Click **"Save"** when done.

### Write to SD Card

1. Click **"Write"** button
2. Confirm when prompted (it will warn you about erasing data)
3. Enter your Mac password if prompted
4. **Wait for completion**:
   - Progress bar will show status
   - Typically takes 5-10 minutes depending on SD card speed
   - Don't remove the SD card during this process!

5. When complete, click **"Continue"**

### Eject SD Card

```bash
# Safely eject
diskutil eject /dev/disk2  # Replace with your disk identifier

# Or use Finder: Right-click SD card → Eject
```

## Step 4: Boot Raspberry Pi

1. **Insert SD card** into Raspberry Pi
2. **Connect peripherals** (if needed):
   - Keyboard/mouse (for initial setup)
   - Monitor/HDMI cable (optional - you can use SSH)
   - Ethernet cable (recommended for first boot)
3. **Connect power supply**
4. **Power on** the Pi

### What to Expect

- **LED indicators**:
  - Red LED: Power (should be steady)
  - Green LED: Activity (will blink during boot)
- **Boot time**: 30-60 seconds typically
- **Network**: Pi will automatically get IP via DHCP

## Step 5: Find Pi's IP Address

After boot, you need to find the Pi's IP address to SSH into it.

### Method 1: Router Admin Panel (Easiest)

1. Log into your router admin panel (usually `192.168.2.1` or `192.168.1.1`)
2. Look for DHCP leases or connected devices
3. Find device named `raspberrypi` or check MAC address
4. Note the IP address

### Method 2: Network Scan

```bash
# Install nmap if needed
brew install nmap

# Scan your network
nmap -sn 192.168.2.0/24 | grep -B 2 "Raspberry Pi"

# Or scan all common ranges
nmap -sn 192.168.1.0/24 192.168.2.0/24
```

### Method 3: mDNS (if available)

```bash
# Try mDNS hostname
ping raspberrypi.local

# If it works, you can SSH with:
ssh pi@raspberrypi.local
```

### Method 4: Check Router DHCP Logs

Most routers show recent DHCP assignments in the admin panel.

## Step 6: Verify SSH Access

Once you have the IP address:

```bash
# SSH to Pi
ssh pi@<PI_IP_ADDRESS>

# Example:
ssh pi@192.168.2.100

# Enter password when prompted (raspberry or what you set)
```

### First SSH Connection

You'll see a message about host key verification:
```
The authenticity of host '192.168.2.100' can't be established.
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Type `yes` and press Enter.

### Test Connection

```bash
# Once connected, verify you're on the Pi
hostname
# Should output: raspberrypi

# Check OS
cat /etc/os-release
# Should show Debian Bookworm

# Update system (optional but recommended)
sudo apt update && sudo apt upgrade -y
```

## Troubleshooting

### SD Card Not Detected

- Try a different USB port
- Check if SD card adapter is working
- Try formatting SD card first (will erase data):
  ```bash
  diskutil eraseDisk FAT32 RPI /dev/disk2  # Replace with your disk
  ```

### Pi Won't Boot

- Check power supply (should be 5V, 3A+ for Pi 5)
- Try different SD card
- Check if SD card is properly inserted
- Try booting with monitor connected to see error messages

### Can't Find Pi on Network

- Check Ethernet cable is connected (if using)
- Check WiFi credentials (if using WiFi)
- Wait longer - first boot can take time
- Check router DHCP settings
- Try connecting monitor/keyboard to Pi directly

### SSH Connection Refused

- Wait a bit longer - SSH service may still be starting
- Check if SSH is enabled in Imager settings
- Try connecting from Pi directly (monitor/keyboard) and check:
  ```bash
  sudo systemctl status ssh
  sudo systemctl start ssh
  ```

### Wrong Password

- Default password is `raspberry` if you didn't change it
- If you changed it in Imager, use that password
- You can reset by re-flashing the SD card

## Next Steps

Once you can SSH into the Pi, proceed to:

1. **Run automated setup**: `./scripts/setup-eldertree.sh`
2. **Or manual setup**: Follow [OS_REINSTALLATION_GUIDE.md](./OS_REINSTALLATION_GUIDE.md)

## Quick Reference

```bash
# Flash OS
1. Open Raspberry Pi Imager
2. Choose OS: Debian Bookworm (64-bit)
3. Choose Storage: Your SD card
4. Configure: Enable SSH, set password
5. Write to SD card
6. Boot Pi

# Find IP
- Check router admin panel
- Or: nmap -sn 192.168.2.0/24

# SSH
ssh pi@<PI_IP>
# Password: raspberry (or what you set)
```

