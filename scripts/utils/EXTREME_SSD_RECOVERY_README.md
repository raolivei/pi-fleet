# Extreme SSD Data Recovery Utility

Comprehensive recovery tool for corrupted APFS volumes on Raspberry Pi. This utility uses PhotoRec to recover files even when Linux cannot see the APFS partition.

## Overview

When an APFS volume becomes corrupted and Linux can only see a portion of the drive (e.g., 476GB instead of 2TB), this tool recovers files by scanning the entire device using file signatures, bypassing filesystem metadata.

## Prerequisites

- Raspberry Pi with SSH access
- Extreme SSD connected to Pi
- Recovery destination with 900+ GB free space
- `sshpass` installed on your Mac
- `tmux` installed on Pi (for long-running operations)

## Quick Start

```bash
# Make script executable
chmod +x scripts/utils/extreme-ssd-recovery.sh

# Run recovery
./scripts/utils/extreme-ssd-recovery.sh
```

The script will:
1. Detect the Extreme SSD
2. Prompt for recovery destination
3. Install required tools (testdisk/PhotoRec)
4. Start PhotoRec in a tmux session
5. Provide instructions for completing the recovery

## Configuration

Edit the script to customize:

```bash
PI_HOST="eldertree.local"      # Your Pi hostname
PI_USER="raolivei"             # SSH username
PI_PASSWORD="Control01!"        # SSH password
```

Or set environment variables:

```bash
export PI_HOST="your-pi.local"
export PI_USER="youruser"
export PI_PASSWORD="yourpass"
./scripts/utils/extreme-ssd-recovery.sh
```

## Recovery Process

### Step 1: Connect to PhotoRec

```bash
ssh raolivei@eldertree.local
tmux attach -t photorec-recovery
```

### Step 2: Complete PhotoRec Setup

In the PhotoRec interface:

1. **Select [Proceed]**
2. **Disk:** Choose `/dev/sda` (or your Extreme SSD device)
3. **Partition:** Select `[Whole disk]` or `[No partition]`
4. **Filesystem:** Select `[Other]` (for APFS/unrecognized)
5. **File types:** Select `[All]` or choose specific types
6. **Destination:** Enter your recovery destination path
7. **Start:** Press `Y` to begin recovery

### Step 3: Detach and Monitor

- **Detach from tmux:** Press `Ctrl+B`, then `D`
- **Recovery continues in background**

### Step 4: Monitor Progress

```bash
# Count recovered directories
ssh raolivei@eldertree.local 'ls -lh /path/to/recovery/recup_dir.* 2>/dev/null | wc -l'

# Check log file
ssh raolivei@eldertree.local 'tail -f /path/to/recovery/photorec.log'

# Check disk usage
ssh raolivei@eldertree.local 'df -h /path/to/recovery'
```

## Recovery Time

- **Small drives (< 500GB):** 4-8 hours
- **Large drives (1-2TB):** 8-24 hours
- **Very large drives (2TB+):** 24-48 hours

Time depends on:
- Drive speed (USB 2.0 vs 3.0)
- Amount of data
- File types being recovered
- Drive health

## Recovery Destinations

### Option 1: External Drive (Recommended)

- Connect external drive to Pi
- Mount it: `sudo mount /dev/sdX1 /mnt/external`
- Use `/mnt/external/recovered_files` as destination

### Option 2: Pi's Internal Storage

- NVME: `/mnt/nvme/recovered_files` (if available)
- SD Card: `/mnt/sd_card/recovered_files` (if available)

### Option 3: Extreme SSD Itself (Risky)

- Use the exFAT partition on the same drive
- Only if you have 900+ GB free
- PhotoRec writes to different partition than source data
- **Warning:** Not recommended for critical data

## What PhotoRec Recovers

PhotoRec recovers files by:
- **File signatures:** Identifies files by their content, not metadata
- **No directory structure:** Files organized by type in `recup_dir.1`, `recup_dir.2`, etc.
- **No original filenames:** Files named `f1234567.jpg`, `f1234568.pdf`, etc.
- **All file types:** Photos, videos, documents, archives, etc.

## Recovered File Organization

```
recovered_files/
├── photorec.log              # Recovery log
└── recup_dir.1/              # First recovery directory
    ├── f0000001.jpg
    ├── f0000002.pdf
    ├── f0000003.mp4
    └── ...
└── recup_dir.2/              # Second recovery directory
    └── ...
```

## Post-Recovery

### Organize Files

```bash
# Create organized structure
mkdir -p organized/{photos,documents,videos,other}

# Move files by extension
find recovered_files/recup_dir.* -name "*.jpg" -exec mv {} organized/photos/ \;
find recovered_files/recup_dir.* -name "*.pdf" -exec mv {} organized/documents/ \;
find recovered_files/recup_dir.* -name "*.mp4" -exec mv {} organized/videos/ \;
```

### Verify Files

```bash
# Check file integrity
file recovered_files/recup_dir.1/f*.jpg | head -10

# Count recovered files
find recovered_files -type f | wc -l

# Check total size
du -sh recovered_files
```

### Backup Recovered Data

```bash
# Copy to multiple locations
rsync -av recovered_files/ /backup/location1/
rsync -av recovered_files/ /backup/location2/
```

## Troubleshooting

### PhotoRec Not Starting

```bash
# Check if tmux session exists
ssh raolivei@eldertree.local 'tmux list-sessions'

# Check PhotoRec process
ssh raolivei@eldertree.local 'ps aux | grep photorec'

# Restart if needed
ssh raolivei@eldertree.local 'tmux kill-session -t photorec-recovery'
# Then run the script again
```

### Out of Space

```bash
# Check available space
ssh raolivei@eldertree.local 'df -h /path/to/recovery'

# Pause PhotoRec (Ctrl+C in tmux)
# Free up space or use different destination
# Resume PhotoRec (it will continue from where it stopped)
```

### Drive Not Detected

```bash
# Rescan USB devices
ssh raolivei@eldertree.local 'sudo partprobe'

# Check dmesg for errors
ssh raolivei@eldertree.local 'dmesg | tail -50'

# List all block devices
ssh raolivei@eldertree.local 'lsblk'
```

### Network Disconnect

- tmux sessions continue running
- Reconnect and attach: `tmux attach -t photorec-recovery`
- Recovery continues automatically

## Related Tools

- `comprehensive-recovery-pi.sh` - Full recovery workflow with disk imaging
- `find-apfs-partition.sh` - Scan for hidden APFS partitions
- `detect-sd-card.sh` - Detect and mount SD cards
- `start-photorec-final.sh` - Quick PhotoRec starter

## Documentation

- `RECOVERY_PROCEDURE.md` - Detailed step-by-step procedure
- `RECOVERY_TOOLS_RESEARCH.md` - Research on recovery tools
- `EXTREME_SSD_NO_FILES_GUIDE.md` - Guide for invisible files issue

## Safety Notes

- **Read-only recovery:** PhotoRec reads from source, writes to destination
- **No data loss:** Source drive is never modified
- **Multiple attempts:** Can run PhotoRec multiple times safely
- **Disk imaging:** Consider creating disk image first (see `comprehensive-recovery-pi.sh`)

## Success Criteria

- Files recovered in `recup_dir.*` directories
- Total recovered size matches expected (~823 GB)
- Files open correctly (verify sample files)
- Recovery log shows no critical errors

## Support

If recovery fails:
1. Check PhotoRec log for errors
2. Verify drive health: `sudo smartctl -a /dev/sda`
3. Try different recovery destination
4. Consider professional data recovery service

## License

This utility is part of the pi-fleet project. Use at your own risk.

