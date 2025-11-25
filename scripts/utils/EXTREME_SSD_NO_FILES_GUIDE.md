# Extreme SSD - Files Not Visible Guide

## Problem
- Volume shows **823.1 GB used** (data exists)
- Finder shows **0 items** (files not visible)
- Terminal access completely blocked (even with sudo)
- Filesystem repair blocked by macOS security

## Root Cause Analysis

This indicates one of the following:

1. **Filesystem Metadata Corruption**: The directory structure/index is corrupted, making files invisible even though they exist
2. **macOS Security Restriction**: Extreme security blocking prevents even admin access
3. **APFS Snapshot/Container Issue**: The volume might be in a corrupted state

## Solutions (In Order of Recommendation)

### Solution 1: Enable Full Disk Access and Repair

**Critical Step**: Enable Full Disk Access for Terminal:

1. System Settings → Privacy & Security → Full Disk Access
2. Enable Terminal (or your terminal app)
3. **Restart your Mac** (required for Full Disk Access to take effect)
4. Then run repair:

```bash
./scripts/utils/disk-repair-tool.sh -a -p "monkeys-37" "/Volumes/Extreme SSD"
```

### Solution 2: Use Disk Utility First Aid (GUI)

Since terminal repair is blocked, use GUI:

```bash
open -a 'Disk Utility'
```

1. Select "Extreme SSD" in sidebar
2. Click "First Aid"
3. Click "Run"
4. Wait for completion
5. Check Finder again

### Solution 3: Data Recovery with PhotoRec

If repair doesn't work, recover files directly:

**Install PhotoRec:**
```bash
brew install testdisk
```

**Run PhotoRec:**
```bash
photorec /log ~/recovered-files/photorec.log /dev/disk5
```

PhotoRec will:
- Scan the entire disk
- Recover files by file type (photos, documents, videos, etc.)
- Save to a destination folder you specify
- Work even with corrupted filesystems

**Note**: PhotoRec recovers files but may not preserve folder structure or filenames.

### Solution 4: Professional Data Recovery

If all else fails:
- **DriveSavers**: drivesavers.com
- **Ontrack**: ontrack.com
- **Cost**: $300-$3000+ depending on damage
- **Success Rate**: Very high for logical corruption (like this)

## Why Terminal Access is Blocked

The volume has `Owners: Disabled` which triggers extreme macOS security:
- Even `sudo` commands are blocked
- This is a macOS security feature, not a bug
- Finder uses different APIs that may also be blocked if metadata is corrupted

## Current Status

- ✅ Volume is mounted
- ✅ Volume shows 823.1 GB used (data exists)
- ❌ Files not visible in Finder
- ❌ Terminal access blocked
- ❌ Filesystem repair blocked (needs Full Disk Access)

## Immediate Actions

1. **Check Finder again** - Hidden files are now visible (enabled)
2. **Try Disk Utility First Aid** (GUI method)
3. **Enable Full Disk Access** and restart Mac, then try repair again
4. **If still no files**: Use PhotoRec to recover files

## Prevention

Once files are recovered:
- **Backup immediately** to another drive
- **Reformat the drive** if needed (after backup!)
- **Enable owners** on the volume if possible

## Files Created

- `recover-extreme-ssd-files.sh`: Interactive recovery script
- `show-hidden-files.sh`: Toggle hidden files in Finder
- `disk-repair-tool.sh`: Comprehensive repair tool

## Next Steps

1. Try Disk Utility First Aid (easiest)
2. Enable Full Disk Access + restart + repair
3. If that fails, use PhotoRec
4. Last resort: Professional recovery

