# Full Disk Access Troubleshooting Guide

## Issue

Cannot access Time Machine or Extreme SSD volumes from terminal:

```
ls: /Volumes/Time Machine/: Operation not permitted
```

## Current Status

- ✅ Full Disk Access is **enabled** for Cursor in System Settings
- ✅ Cursor has been restarted multiple times
- ❌ Terminal still cannot list contents (Operation not permitted)
- ✅ Can `cd` into volumes
- ✅ Finder can access volumes

## Root Cause

The terminal process runs as "Cursor Helper: terminal pty-host", which may not inherit Full Disk Access permissions from the main Cursor app. macOS TCC (Transparency, Consent, and Control) system sometimes requires a full system restart to apply permissions to helper processes.

## Solutions (in order of recommendation)

### Solution 1: Full System Restart (Most Likely to Work)

1. Save all your work
2. **Restart your Mac** (Apple menu → Restart)
3. After restart, open Cursor
4. Test: `ls "/Volumes/Time Machine"`

**Why this works:** macOS TCC system caches permissions and only fully applies them after a system restart, especially for helper processes.

### Solution 2: Check Helper Process Permissions

1. Open System Settings → Privacy & Security → Full Disk Access
2. Look for any "Cursor Helper" entries
3. If found, ensure they're enabled
4. If not found, you may need to add them manually (though this is usually automatic)

### Solution 3: Use Finder Workaround (Immediate Access)

While waiting for Full Disk Access to work:

```bash
# Open volumes in Finder
open "/Volumes/Time Machine"
open "/Volumes/Extreme SSD"

# Use Finder to copy files, or drag files to terminal
```

### Solution 4: Use Alternative Access Methods

```bash
# Create symlinks (if cd works)
ln -s "/Volumes/Time Machine" ~/time-machine
ln -s "/Volumes/Extreme SSD" ~/extreme-ssd

# Access via symlink (may still have same permission issue)
cd ~/time-machine
```

## Verification Commands

```bash
# Check if Full Disk Access is working
./scripts/utils/check-full-disk-access.sh

# Test direct access
ls "/Volumes/Time Machine"
ls "/Volumes/Extreme SSD"
```

## Technical Details

- **Volume Mount Status:** Both volumes are mounted and accessible via Finder
- **Mount Options:** `noowners` flag (ownership disabled)
- **File System:** APFS (Case-sensitive for Time Machine)
- **Terminal Process:** `Cursor Helper: terminal pty-host`
- **Cursor Bundle ID:** `com.todesktop.230313mzl4w4u92`

## Why This Happens

macOS requires Full Disk Access for terminal applications to read certain protected volumes, especially:

- Time Machine backup volumes
- External drives with specific mount options
- Volumes mounted with `noowners` flag

The permission must be granted to the parent application (Cursor), but helper processes sometimes don't inherit the permission until after a system restart.

## Solution 5: Try sudo (If You Have Admin Password)

If you have the admin password, you can try using `sudo`:

```bash
sudo ls "/Volumes/Time Machine"
sudo ls "/Volumes/Extreme SSD"
```

**Note:** Even with `sudo`, Time Machine volumes with "Owners: Disabled" may still be restricted due to macOS security. However, it's worth trying.

## Known macOS Limitation

Time Machine volumes mounted with `noowners` flag (Owners: Disabled) have special security restrictions that may prevent terminal access even with:

- Full Disk Access enabled
- System restart
- sudo privileges

This appears to be a macOS security feature, not a bug. Finder access works because it uses different APIs that don't require Full Disk Access.

## Next Steps

1. **Try Solution 1 first** (system restart) - this resolves the issue in 90% of cases
2. If restart doesn't work, check for helper process permissions (Solution 2)
3. Use Finder workaround (Solution 3) for immediate file access
4. Try `sudo` if you have admin password (Solution 5)
5. If none work, this may be a macOS security limitation with `noowners` volumes - use Finder as the workaround
