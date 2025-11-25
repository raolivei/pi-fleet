# SanDisk Extreme SSD Data Recovery Guide

## Situation

- **Drive**: SanDisk Extreme 55AE (2TB USB flash drive)
- **Status**: Untouched for ~1 year
- **Issue**: Cannot read partition data via terminal (macOS permission restrictions)
- **Volume**: Mounted at `/Volumes/Extreme SSD` (disk8s1)

## Current Status

- ✅ Drive is recognized by macOS
- ✅ Partition is mounted
- ✅ Can `cd` into the volume
- ❌ Cannot list files (`ls`, `find`, Python, Ruby all blocked)
- ✅ Finder can access the volume

## Recovery Methods (Try in Order)

### Method 1: Filesystem Repair (NON-DESTRUCTIVE)

**Run in terminal (requires admin password):**

```bash
# Step 1: Verify filesystem (read-only check)
sudo diskutil verifyVolume "/Volumes/Extreme SSD"

# Step 2: If errors found, repair (NON-DESTRUCTIVE)
sudo diskutil repairVolume "/Volumes/Extreme SSD"
```

**Or use Disk Utility GUI:**

```bash
open -a 'Disk Utility'
```

1. Select "Extreme SSD" in sidebar
2. Click "First Aid"
3. Click "Run"
4. Wait for completion

### Method 2: Use Finder to Access Files

Since terminal access is blocked, use Finder:

```bash
# Open volume in Finder
open "/Volumes/Extreme SSD"
```

**In Finder:**

- Browse files normally
- To get file paths: Select file → `Cmd+Option+C` (copies path)
- To copy files: Drag to another location
- To see file info: Select file → `Cmd+I`

### Method 3: Filesystem Check with fsck_apfs

**Run in terminal (requires admin password):**

```bash
# Unmount first
diskutil unmount "/Volumes/Extreme SSD"

# Check filesystem (read-only)
sudo fsck_apfs -n /dev/disk8s1

# If errors found, repair
sudo fsck_apfs -y /dev/disk8s1

# Remount
diskutil mount disk8s1
```

### Method 4: Check Physical Disk Health

```bash
# Check the physical disk
diskutil info disk5

# Verify the physical disk partition table
sudo diskutil verifyDisk disk5
```

### Method 5: Data Recovery Software

If filesystem is corrupted, use data recovery tools:

**Free Options:**

- **PhotoRec** (TestDisk) - Recovers files by file type
- **Disk Drill** (free version) - GUI data recovery

**Install PhotoRec:**

```bash
brew install testdisk
```

**Use PhotoRec:**

```bash
photorec /log /dev/disk5
```

### Method 6: Professional Data Recovery

If all else fails:

- Drive may have hardware issues
- Professional data recovery services can recover data even from damaged drives
- Cost: $300-$3000+ depending on damage

## Troubleshooting Steps

### Step 1: Check if Volume is Accessible

```bash
cd "/Volumes/Extreme SSD"
pwd
stat .
```

### Step 2: Try to Repair

```bash
sudo diskutil repairVolume "/Volumes/Extreme SSD"
```

### Step 3: Check Disk Health

```bash
./scripts/utils/check-disk-health.sh "/Volumes/Extreme SSD"
```

### Step 4: Use Finder

```bash
open "/Volumes/Extreme SSD"
```

## Why Terminal Access is Blocked

The volume has `Owners: Disabled` which triggers macOS security restrictions:

- Terminal commands are blocked even with Full Disk Access
- This is a macOS security feature, not a drive problem
- Finder uses different APIs that bypass these restrictions

## Expected Outcomes

### Best Case:

- Filesystem repair fixes any corruption
- Files are accessible via Finder
- Can copy files to another location

### Worst Case:

- Filesystem is severely corrupted
- Need data recovery software
- May need professional recovery service

## Next Steps

1. **Try Method 1 first** (Disk Utility First Aid)
2. **If that doesn't work**, use Finder to access files
3. **If Finder can't see files**, try Method 3 (fsck_apfs)
4. **If still no access**, try data recovery software (Method 5)
5. **Last resort**: Professional data recovery service

## Important Notes

- ⚠️ **DO NOT reformat** the drive until you've recovered all data
- ✅ All repair operations are **NON-DESTRUCTIVE**
- 💾 **Backup immediately** once you can access files
- 🔒 The drive may need to be unmounted during repair (normal and safe)

## Quick Commands Reference

```bash
# Check disk health
./scripts/utils/check-disk-health.sh "/Volumes/Extreme SSD"

# Repair disk (safe)
./scripts/utils/repair-disk-safe.sh "/Volumes/Extreme SSD"

# Open in Finder
open "/Volumes/Extreme SSD"

# Verify filesystem
sudo diskutil verifyVolume "/Volumes/Extreme SSD"

# Repair filesystem
sudo diskutil repairVolume "/Volumes/Extreme SSD"
```
