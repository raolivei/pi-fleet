# Disk Repair Tool

Comprehensive disk repair utility for macOS that handles unmounting, filesystem repair, and remounting of volumes.

## Features

- **Automatic Process Management**: Closes Finder windows and processes using the volume
- **Force Unmount**: Safely force-unmounts volumes that can't be unmounted normally
- **Multiple Repair Methods**: Tries diskutil and fsck_apfs for maximum compatibility
- **Non-Destructive**: Only repairs filesystem structure, preserves all data
- **Auto Mode**: Can run non-interactively for automation
- **Colored Output**: Easy-to-read status messages
- **Comprehensive Logging**: Saves repair output to `/tmp/repair_output.log`

## Usage

### Basic Usage

```bash
./scripts/utils/disk-repair-tool.sh "/Volumes/Extreme SSD"
```

### With Password (Non-Interactive)

```bash
./scripts/utils/disk-repair-tool.sh -p "yourpassword" "/Volumes/Extreme SSD"
```

### Auto Mode (No Prompts)

```bash
./scripts/utils/disk-repair-tool.sh -a -p "yourpassword" "/Volumes/Extreme SSD"
```

### Help

```bash
./scripts/utils/disk-repair-tool.sh --help
```

## Options

- `-p, --password PASSWORD`: Provide admin password for sudo operations
- `-a, --auto`: Auto mode (non-interactive, skips confirmations)
- `-h, --help`: Show help message

## What It Does

1. **Closes Processes**: Closes Finder windows and checks for processes using the volume
2. **Force Unmounts**: Safely unmounts the volume (required for repair)
3. **Repairs Filesystem**: Runs filesystem repair using multiple methods
4. **Verifies Repair**: Runs read-only verification to confirm repair success
5. **Remounts Volume**: Automatically remounts the volume after repair
6. **Tests Access**: Verifies the volume is accessible via cd and Finder

## Supported Filesystems

- APFS (Apple File System) - Primary support
- HFS+ (Mac OS Extended) - Via diskutil
- Other macOS-compatible filesystems

## Requirements

- macOS (tested on macOS 15.6.1)
- Admin/sudo access
- Terminal with Full Disk Access (for fsck_apfs - may not be required for diskutil)

## Known Limitations

### Permission Errors (Exit Code 66)

If you see:
```
error: device /dev/rdisk8 failed to open with error: Operation not permitted
```

This is a macOS security restriction. Solutions:

1. **Enable Full Disk Access**:
   - System Settings → Privacy & Security → Full Disk Access
   - Enable Terminal (or your terminal app)
   - Restart Terminal

2. **Use Disk Utility GUI**:
   ```bash
   open -a 'Disk Utility'
   ```
   Then use First Aid feature

3. **Use Finder**: The volume is still accessible via Finder even if terminal repair fails

### Terminal File Access Blocked

If terminal commands like `ls` don't work but Finder does:

- This is normal for volumes with `Owners: Disabled`
- Use Finder to access files: `open "/Volumes/Extreme SSD"`
- This is a macOS security feature, not a filesystem problem

## Examples

### Repair Time Machine Volume

```bash
./scripts/utils/disk-repair-tool.sh "/Volumes/Time Machine"
```

### Repair External Drive (Auto Mode)

```bash
./scripts/utils/disk-repair-tool.sh -a -p "mypassword" "/Volumes/My External Drive"
```

### Repair and Check Logs

```bash
./scripts/utils/disk-repair-tool.sh "/Volumes/Extreme SSD"
cat /tmp/repair_output.log
```

## Safety

- ✅ **NON-DESTRUCTIVE**: Only repairs filesystem structure
- ✅ **Data Preserved**: Your files are safe
- ✅ **Automatic Remount**: Volume is automatically remounted after repair
- ✅ **Error Handling**: Gracefully handles errors and continues when possible

## Troubleshooting

### Volume Won't Unmount

The tool automatically tries:
1. Regular unmount
2. Force unmount
3. Unmount entire disk

If all fail, manually close applications using the volume.

### Repair Fails with Permission Error

1. Enable Full Disk Access for Terminal
2. Or use Disk Utility GUI instead
3. Volume is still accessible via Finder

### Volume Not Found After Remount

The tool will try to find the volume automatically. Check:
```bash
diskutil list
mount | grep "Extreme SSD"
```

## Output Files

- `/tmp/repair_output.log`: Detailed repair output for troubleshooting

## Exit Codes

- `0`: Success
- `1`: Error (volume not found, unmount failed, etc.)

## Integration

Can be used in scripts or automation:

```bash
#!/bin/bash
if ./scripts/utils/disk-repair-tool.sh -a -p "$PASSWORD" "/Volumes/Extreme SSD"; then
    echo "Repair successful"
else
    echo "Repair failed, check logs"
fi
```

## Related Tools

- `check-disk-health.sh`: Check disk health without repair
- `repair-disk-safe.sh`: Interactive repair script
- `EXTREME_SSD_RECOVERY_GUIDE.md`: Comprehensive recovery guide

