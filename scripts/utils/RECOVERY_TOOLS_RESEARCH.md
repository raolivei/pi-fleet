# Disk Recovery Tools - Deep Research & Best Practices

## Overview

This document provides comprehensive research on disk recovery tools and methods for recovering data from corrupted APFS filesystems, specifically for the SanDisk Extreme SSD recovery operation.

## Tool Categories

### 1. File Signature-Based Recovery Tools

#### PhotoRec (Part of TestDisk)
**Purpose**: Recovers files by file signatures, bypassing filesystem entirely

**Strengths**:
- Works even with completely corrupted filesystems
- Recovers files by type (photos, documents, videos, etc.)
- Free and open source
- Cross-platform (Linux, macOS, Windows)
- Handles bad sectors gracefully
- Can recover from formatted drives

**Limitations**:
- Doesn't preserve directory structure
- Doesn't preserve filenames
- Organizes by file type only
- May recover false positives
- Slower than filesystem-based recovery

**Best Practices**:
- Run on entire disk or disk image (not mounted partition)
- Use log file for tracking: `photorec /log recovery.log /dev/sdX`
- Recover to different drive than source
- Verify recovered files after completion
- Use specific file types if you know what you're looking for

**Installation (Debian/Raspberry Pi)**:
```bash
sudo apt-get update
sudo apt-get install -y testdisk
```

**Usage**:
```bash
photorec /log /path/to/recovery.log /dev/sdX
# Interactive mode - select disk, partition, filesystem, destination
```

#### TestDisk (Part of same package)
**Purpose**: Partition recovery and filesystem repair

**Use Cases**:
- Recover deleted partitions
- Fix partition tables
- Rebuild boot sectors
- Recover filesystem structures

**For APFS**: Limited support, primarily for partition recovery

### 2. Sector-by-Sector Disk Imaging

#### GNU ddrescue
**Purpose**: Create exact disk images, handling bad sectors intelligently

**Strengths**:
- Handles bad sectors gracefully (doesn't stop on errors)
- Can resume interrupted operations
- Creates exact bit-for-bit copy
- Works with any filesystem
- Essential for hardware-level recovery

**Best Practices**:
- Always create disk image before recovery attempts
- Use log file to resume: `ddrescue -l logfile /dev/sdX image.img`
- Run multiple passes for bad sectors
- Verify image after creation
- Use image for recovery (protects original)

**Installation**:
```bash
sudo apt-get install -y gddrescue
```

**Usage**:
```bash
# First pass - fast, skip bad sectors
ddrescue -f -n /dev/sdX image.img logfile.log

# Second pass - retry bad sectors
ddrescue -d -f -r3 /dev/sdX image.img logfile.log

# Verify
ddrescue -v /dev/sdX image.img logfile.log
```

#### dd (Standard tool)
**Purpose**: Basic disk imaging

**Limitations**: Stops on first error, no resume capability
**Use Case**: Only if ddrescue unavailable

### 3. APFS-Specific Tools for Linux

#### apfs-fuse
**Purpose**: FUSE-based APFS filesystem driver for Linux

**Capabilities**:
- Read-only mount of APFS volumes
- Access files if metadata is intact
- Preserves directory structure and filenames
- Works with encrypted APFS (if key available)

**Limitations**:
- Read-only (no write support)
- May not work with severely corrupted metadata
- Performance slower than native

**Installation**:
```bash
sudo apt-get install -y apfs-fuse
```

**Usage**:
```bash
# Mount read-only
sudo apfs-fuse /dev/sdX1 /mnt/apfs -o allow_other

# List files
ls -lah /mnt/apfs

# Copy files
cp -r /mnt/apfs/* /destination/
```

#### apfsprogs
**Purpose**: Command-line tools for APFS manipulation

**Tools Included**:
- `apfsck`: Check and repair APFS filesystem
- `apfsutil`: APFS utilities
- `apfs-fuse`: FUSE driver

**Status**: Limited availability, may need to compile from source

**Installation** (if available):
```bash
sudo apt-get install -y apfsprogs
# Or compile from source
```

### 4. Drive Health Monitoring

#### smartctl (smartmontools)
**Purpose**: Monitor drive health via SMART attributes

**Use Cases**:
- Check drive health before recovery
- Identify hardware issues
- Predict drive failure
- Monitor during recovery

**Installation**:
```bash
sudo apt-get install -y smartmontools
```

**Usage**:
```bash
# Check SMART status
sudo smartctl -a /dev/sdX

# Run short self-test
sudo smartctl -t short /dev/sdX

# Check test results
sudo smartctl -l selftest /dev/sdX
```

### 5. File Verification Tools

#### md5sum / sha256sum
**Purpose**: Verify file integrity

**Use Cases**:
- Verify recovered files aren't corrupted
- Compare source and recovered files
- Create checksums for verification

**Usage**:
```bash
# Create checksum
md5sum file.txt > file.txt.md5

# Verify
md5sum -c file.txt.md5
```

#### file
**Purpose**: Identify file types

**Use Cases**:
- Verify recovered files are correct type
- Identify corrupted files
- Organize recovered files

## Recovery Strategy for APFS Corruption

### Scenario: Metadata Corruption (Files Invisible)

**Symptoms**:
- Drive shows data used (823 GB) but 0 files visible
- Filesystem mounts but directory listing fails
- Terminal access blocked (macOS security)

**Recovery Approach**:

1. **Create Disk Image First** (ddrescue)
   - Protects original drive
   - Allows multiple recovery attempts
   - Handles bad sectors

2. **Try APFS Mount** (apfs-fuse)
   - If metadata partially intact, may see files
   - Preserves structure and filenames
   - Fastest recovery if it works

3. **PhotoRec Recovery** (if mount fails)
   - Bypasses filesystem entirely
   - Recovers by file signatures
   - Slower but more thorough

4. **Combine Results**
   - Use mount results for structure
   - Use PhotoRec for missing files
   - Verify all recovered files

## Best Practices Summary

### Before Recovery
1. **Never write to source drive** (except recovery destination if using same drive)
2. **Create disk image** with ddrescue
3. **Check drive health** with smartctl
4. **Document everything** (device paths, sizes, timestamps)

### During Recovery
1. **Use tmux** for long operations
2. **Monitor progress** regularly
3. **Verify space** on destination
4. **Log all operations**
5. **Don't interrupt** recovery processes

### After Recovery
1. **Verify files** open correctly
2. **Check file counts** and sizes
3. **Compare to expected** (823 GB)
4. **Create backups** immediately
5. **Document recovery** report

## Tool Comparison Matrix

| Tool | Speed | Structure | Filenames | Bad Sectors | APFS Support |
|------|-------|-----------|-----------|-------------|--------------|
| apfs-fuse | Fast | ✅ | ✅ | Limited | ✅ Read-only |
| PhotoRec | Slow | ❌ | ❌ | ✅ | ✅ (bypasses FS) |
| ddrescue | Medium | N/A | N/A | ✅ | ✅ (any FS) |
| TestDisk | Fast | ✅ | ✅ | Limited | Limited |

## Recovery Time Estimates

For 2TB drive with 823 GB used:

- **ddrescue image**: 4-8 hours (depends on bad sectors)
- **apfs-fuse mount**: 5-10 minutes (if it works)
- **PhotoRec recovery**: 8-24 hours (depends on file types)
- **File verification**: 2-4 hours
- **Organization**: 1-2 hours

**Total**: 15-38 hours (most can run unattended)

## References

- PhotoRec Documentation: https://www.cgsecurity.org/wiki/PhotoRec
- TestDisk Documentation: https://www.cgsecurity.org/wiki/TestDisk
- ddrescue Manual: https://www.gnu.org/software/ddrescue/
- apfs-fuse GitHub: https://github.com/sgan81/apfs-fuse
- APFS Specification: Apple File System Reference

