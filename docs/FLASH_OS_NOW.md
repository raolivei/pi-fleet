# Flash OS to SD Card - Step by Step

Follow these exact steps to flash Debian Bookworm to your SD card.

## Prerequisites Check

✅ Raspberry Pi Imager is installed
✅ You have a microSD card ready
✅ You have an SD card reader/adapter

## Step-by-Step Instructions

### Step 1: Insert SD Card

1. Insert your microSD card into your Mac (using adapter if needed)
2. **⚠️ IMPORTANT**:
   - This will **erase everything on the SD card**
   - **USB backup drive is safe** - it's a separate device and won't be touched
   - **No manual formatting needed** - Imager handles format + install automatically

### Step 2: Open Raspberry Pi Imager

```bash
# Open from terminal
open -a "Raspberry Pi Imager"

# Or find it in Applications → Raspberry Pi Imager
```

### Step 3: Choose Operating System

1. Click the **"Choose OS"** button (left side)
2. Scroll down and click **"Other general-purpose OS"**
3. Click **"Debian"**
4. Select your Debian version:

   - **"Debian Trixie (64-bit)"** ← **Recommended** (Latest stable, Debian 13)
   - **"Debian Bookworm (64-bit)"** ← Alternative (Debian 12, matches current docs)

   **Which to choose?**

   - **Trixie**: Latest stable, newer packages, recommended for fresh installs
   - **Bookworm**: More conservative, matches existing documentation exactly

   **Both work fine with k3s!** Choose based on preference.

### Step 4: Choose Storage

1. Click the **"Choose Storage"** button (middle)
2. Select your microSD card from the list
3. **⚠️ DOUBLE-CHECK**: Make absolutely sure you selected the SD card, NOT your Mac's internal drive!
   - Look for the card's name/capacity
   - Usually shows as something like "NO NAME" or the card's brand name

### Step 5: Configure Settings (CRITICAL)

Click the **gear icon (⚙️)** in the bottom right corner.

#### Essential Settings:

1. **Enable SSH**: ✅ **CHECK THIS BOX** (required!)
2. **Set username**: `pi` (default is fine)
3. **Set password**:
   - Default: `raspberry` (you can use this)
   - Or set your own password (remember it!)
4. **SSH public key** (optional): Leave empty for now

#### Network Settings (Optional):

- **Configure wireless LAN**:
  - Check if you want WiFi
  - Enter your WiFi SSID and password
  - Select country

#### Advanced Options (Optional):

- **Set hostname**: Leave as `raspberrypi` (we'll change it later)
- **Set locale settings**:
  - Timezone: `America/Toronto` (or your timezone)
  - Keyboard layout: `us` (or your layout)

Click **"Save"** when done.

### Step 6: Write to SD Card

1. Click the **"Write"** button (right side)
2. You'll see a warning: **"This will erase all data on the selected drive"**
3. **Confirm** by clicking **"Yes"**
4. Enter your Mac password if prompted
5. **Wait for completion**:

   - Progress bar will show: "Writing image..."
   - This typically takes 5-10 minutes
   - **DO NOT** remove the SD card during this process!
   - **DO NOT** close the application!

6. When complete, you'll see: **"Write Successful"**
7. Click **"Continue"**

### Step 7: Eject SD Card Safely

```bash
# Find your SD card disk
diskutil list

# Eject it (replace disk2 with your actual disk)
diskutil eject /dev/disk2

# Or use Finder: Right-click SD card → Eject
```

### Step 8: Insert SD Card into Raspberry Pi

1. **Safely remove** the SD card from your Mac
2. **Insert** it into your Raspberry Pi
3. **Connect**:
   - Ethernet cable (recommended for first boot)
   - Power supply
4. **Power on** the Pi

### Step 9: Wait for Boot

- **Red LED**: Power (should be steady)
- **Green LED**: Activity (will blink during boot)
- **Boot time**: 30-60 seconds typically
- The Pi will automatically get an IP address via DHCP

## Next Steps

After the Pi boots:

1. **Find the Pi's IP address**:

   - Check your router admin panel (look for device named `raspberrypi`)
   - Or scan network: `nmap -sn 192.168.2.0/24`

2. **SSH to the Pi**:

   ```bash
   ssh pi@<PI_IP_ADDRESS>
   # Password: raspberry (or what you set)
   ```

3. **Run automated setup**:
   ```bash
   cd ~/WORKSPACE/raolivei/pi-fleet
   ./scripts/setup/setup-eldertree.sh
   ```

## Troubleshooting

### SD Card Not Showing Up

- Try a different USB port
- Check if SD card adapter is working
- Try formatting SD card first (will erase data):
  ```bash
  diskutil eraseDisk FAT32 RPI /dev/disk2  # Replace with your disk
  ```

### Write Fails

- Try a different SD card
- Check SD card isn't write-protected (switch on side)
- Try a different USB port/adapter

### Pi Won't Boot After Flashing

- Check power supply (5V, 3A+ for Pi 5)
- Try different SD card
- Check SD card is properly inserted
- Try booting with monitor connected to see errors

## Quick Checklist

- [ ] SD card inserted into Mac
- [ ] Raspberry Pi Imager opened
- [ ] OS selected: **Debian Bookworm (64-bit)**
- [ ] Storage selected: **Your SD card** (not Mac drive!)
- [ ] Settings configured: **SSH enabled**, password set
- [ ] Write completed successfully
- [ ] SD card ejected safely
- [ ] SD card inserted into Pi
- [ ] Pi powered on and booted

## Summary

You're flashing:

- **OS**: Debian Bookworm (64-bit)
- **Username**: `pi`
- **Password**: `raspberry` (or your choice)
- **SSH**: Enabled ✅

After boot, find the IP and SSH in, then run the setup script!
