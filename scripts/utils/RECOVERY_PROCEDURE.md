# Step-by-Step Recovery Procedure

## Pre-Recovery Checklist

- [ ] Extreme SSD connected to Raspberry Pi
- [ ] Pi is accessible via SSH (eldertree.local)
- [ ] Recovery destination drive connected (or using Extreme SSD itself)
- [ ] At least 900 GB free space on recovery destination
- [ ] Network connection stable
- [ ] tmux installed on Pi
- [ ] Sufficient time allocated (20-48 hours)

## Quick Start

```bash
# Run comprehensive recovery script
./scripts/utils/comprehensive-recovery-pi.sh
```

The script will:
1. Detect the Extreme SSD
2. Check drive health
3. Ask you to select recovery destination
4. Install required tools
5. Create disk image (optional but recommended)
6. Attempt APFS mount
7. Run PhotoRec if needed
8. All in tmux sessions for long operations

## Detailed Procedure

### Step 1: Connect and Verify

1. Connect Extreme SSD to Raspberry Pi USB port
2. SSH to Pi: `sshpass -p 'Control01!' ssh raolivei@eldertree.local`
3. Verify drive detected: `lsblk`
4. Note device name (e.g., `/dev/sda`, `/dev/sdb`)

### Step 2: Check Drive Health

```bash
# Install smartmontools if needed
sudo apt-get install -y smartmontools

# Check SMART status
sudo smartctl -a /dev/sdX
```

Look for:
- Reallocated sectors (should be 0)
- Current pending sector (should be 0)
- Overall health status

### Step 3: Select Recovery Destination

**Option A: Use Extreme SSD itself**
- Requires at least 900 GB free space
- Recovered files on same drive
- Convenient but less safe

**Option B: Use external drive**
- Recommended for critical data
- Separate from source drive
- More reliable

**Option C: Use Pi's storage**
- Only if Pi has enough space
- May be slower (SD card)

### Step 4: Install Recovery Tools

```bash
sudo apt-get update
sudo apt-get install -y testdisk gddrescue apfs-fuse smartmontools
```

Verify installation:
```bash
which photorec ddrescue apfs-fuse smartctl
```

### Step 5: Create Disk Image (Recommended)

**Why**: Protects original, allows multiple attempts

```bash
# Create tmux session
tmux new -s ddrescue-backup

# Start ddrescue (first pass - fast)
sudo ddrescue -f -n /dev/sdX /path/to/image.img /path/to/logfile.log

# Detach: Ctrl+B, then D
# Reattach: tmux attach -t ddrescue-backup

# After first pass, retry bad sectors
sudo ddrescue -d -f -r3 /dev/sdX /path/to/image.img /path/to/logfile.log
```

**Time**: 4-8 hours for 2TB drive

### Step 6: Attempt APFS Mount

```bash
# Create mount point
sudo mkdir -p /mnt/extreme_ssd

# Find APFS partition
sudo blkid /dev/sdX*

# Mount read-only
sudo apfs-fuse /dev/sdX1 /mnt/extreme_ssd -o allow_other

# Check if mounted
mount | grep extreme_ssd

# List files
ls -lah /mnt/extreme_ssd
```

**If successful**: Files are accessible! Extract them.

**If failed**: Metadata corrupted, proceed to PhotoRec.

### Step 7: Extract Files from APFS Mount

```bash
# Create extraction directory
sudo mkdir -p /path/to/recovery/apfs_extracted

# Extract files (in tmux)
tmux new -s apfs-extract
sudo rsync -av --progress /mnt/extreme_ssd/ /path/to/recovery/apfs_extracted/
# Detach and let it run
```

**Time**: 2-4 hours for 823 GB

### Step 8: PhotoRec Recovery (If APFS Failed)

```bash
# Create recovery directory
sudo mkdir -p /path/to/recovery/photorec_recovered

# Start PhotoRec in tmux
tmux new -s photorec-recovery
cd /path/to/recovery/photorec_recovered
photorec /log photorec.log /dev/sdX
```

**PhotoRec Interactive Steps**:
1. Select disk (choose the Extreme SSD)
2. Select partition (or "Whole disk")
3. Select filesystem (choose "Other" for APFS)
4. Select destination (choose recovery directory)
5. Start recovery

**Time**: 8-24 hours depending on file types

### Step 9: Verify Recovered Files

```bash
# Count files
find /path/to/recovery -type f | wc -l

# Check total size
du -sh /path/to/recovery/*

# Verify some files open
file /path/to/recovery/photorec_recovered/recup_dir.1/f*.jpg | head -10
```

### Step 10: Organize and Backup

```bash
# Create organized structure
mkdir -p /path/to/recovery/organized/{photos,documents,videos,other}

# Move files by type (example)
find /path/to/recovery/photorec_recovered -name "*.jpg" -exec mv {} /path/to/recovery/organized/photos/ \;
find /path/to/recovery/photorec_recovered -name "*.pdf" -exec mv {} /path/to/recovery/organized/documents/ \;
```

### Step 11: Copy to Final Destination

```bash
# Copy to external drive or back to Mac
rsync -av --progress /path/to/recovery/ /mnt/external_drive/recovered/
```

## Monitoring Progress

### Check tmux Sessions

```bash
# List sessions
tmux list-sessions

# Attach to session
tmux attach -t session-name

# Detach: Ctrl+B, then D
```

### Monitor Disk Usage

```bash
# Watch disk usage
watch -n 60 'df -h /path/to/recovery'
```

### Check Logs

```bash
# PhotoRec log
tail -f /path/to/recovery/photorec_recovered/photorec.log

# ddrescue log
tail -f /path/to/recovery/ddrescue.log
```

## Troubleshooting

### Drive Not Detected
- Check USB connection
- Try different USB port
- Check `dmesg | tail -50` for errors
- Verify drive powers on

### APFS Mount Fails
- Normal if metadata corrupted
- Proceed to PhotoRec
- Try different partition if multiple exist

### PhotoRec Slow
- Normal for large drives
- Can take 24+ hours
- Let it run, don't interrupt

### Out of Space
- Check: `df -h`
- Free up space or use different destination
- Can pause and resume PhotoRec

### Network Disconnect
- tmux sessions continue running
- Reconnect and attach to sessions
- All operations are logged

## Recovery Time Estimates

| Operation | Time | Can Pause? |
|-----------|------|------------|
| Disk Image (ddrescue) | 4-8 hours | Yes (resume) |
| APFS Mount | 5-10 min | No |
| APFS Extract | 2-4 hours | Yes |
| PhotoRec | 8-24 hours | Yes (resume) |
| Verification | 2-4 hours | Yes |
| Organization | 1-2 hours | Yes |

**Total**: 15-38 hours (most unattended)

## Success Indicators

- ✅ Files visible in APFS mount OR
- ✅ Files recovered by PhotoRec
- ✅ Total recovered size ~823 GB
- ✅ Files open correctly
- ✅ File types match expectations

## Next Steps After Recovery

1. **Verify all critical files** are recovered
2. **Backup to multiple locations**
3. **Organize files** by type/date
4. **Document what was recovered**
5. **Consider drive replacement** (if hardware issues found)

