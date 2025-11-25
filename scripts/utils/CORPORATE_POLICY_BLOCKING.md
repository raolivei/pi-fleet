# Corporate Policy Blocking Disk Access

## Root Cause Identified

The disk access issues are likely caused by **corporate security policies**:
- **Jamf (MDM)**: Mobile Device Management policies
- **Zscaler**: Network security and endpoint protection policies

These tools can block:
- Direct disk device access (`/dev/rdisk*`)
- Filesystem repair operations
- Even with admin/sudo privileges
- This is **intentional security policy**, not a bug

## What Corporate Policies Block

### Jamf Policies Can Block:
- Full Disk Access permissions
- Direct device access
- Filesystem repair tools
- Certain terminal commands
- Even Disk Utility operations

### Zscaler Policies Can Block:
- Network-based security restrictions
- Endpoint protection that monitors disk access
- Policy enforcement that prevents low-level disk operations

## Solutions Within Corporate Restrictions

### Option 1: Contact IT Support

**This is the recommended approach for company assets:**

1. **Contact your IT department**
2. **Explain the situation:**
   - External drive (Extreme SSD) has 823 GB of data
   - Files are not visible (likely metadata corruption)
   - Need to recover data
   - Corporate policies are blocking repair tools

3. **Request:**
   - Temporary exception for data recovery
   - Or IT can run repair tools on your behalf
   - Or IT can approve PhotoRec/data recovery software

### Option 2: Try Workarounds (May Still Be Blocked)

**Note**: These may also be blocked by policies, but worth trying:

1. **Use Personal Device** (if allowed by company policy):
   - Connect drive to personal Mac/PC
   - Run repair/recovery tools there
   - No corporate restrictions

2. **Boot from External OS** (if allowed):
   - Boot from USB drive with macOS/Linux
   - Bypasses corporate policies
   - Check company policy first!

3. **Use IT-Approved Tools**:
   - Ask IT for approved data recovery tools
   - They may have enterprise licenses
   - Tools may be whitelisted in policies

### Option 3: PhotoRec (May Also Be Blocked)

PhotoRec might work if it doesn't require direct device access:

```bash
# Try installing (may be blocked)
brew install testdisk

# Try running (may be blocked)
photorec /log ~/recovered-files/photorec.log /dev/disk5
```

**If blocked**: Contact IT to whitelist PhotoRec or approve data recovery.

## Why This Happens

Corporate security policies are designed to:
- Prevent unauthorized data access
- Protect against malware
- Ensure compliance
- Prevent data exfiltration

These policies can be **overly restrictive** for legitimate use cases like data recovery.

## What to Tell IT

**Template for IT Request:**

```
Subject: Request for Disk Access Exception - Data Recovery

Hi IT Support,

I have an external USB drive (SanDisk Extreme SSD) that:
- Contains 823 GB of personal/work data
- Shows files are not visible (likely filesystem metadata corruption)
- Cannot be repaired due to corporate security policies blocking disk access

The drive shows:
- 823.1 GB used (data exists)
- 0 files visible in Finder
- All repair attempts blocked with "Operation not permitted"

I need to recover this data. Could you please:
1. Temporarily grant exception for data recovery tools, OR
2. Run repair/recovery tools on my behalf, OR
3. Approve/whitelist PhotoRec or similar data recovery tool

This is urgent as the data may be at risk.

Thank you,
[Your Name]
```

## Alternative: Personal Device Recovery

If company policy allows:

1. **Connect drive to personal Mac/PC**
2. **Run repair/recovery there**
3. **No corporate restrictions**
4. **Recover data to personal device**
5. **Transfer back to work device if needed**

**Check company policy first** - some companies prohibit connecting external drives to personal devices.

## What Corporate Policies Typically Allow

Even with restrictions, you can usually:
- ✅ Access files via Finder (if filesystem is intact)
- ✅ Copy files to another location
- ✅ Use approved backup tools
- ✅ Access network drives

You usually **cannot**:
- ❌ Access raw disk devices
- ❌ Run filesystem repair tools
- ❌ Bypass security policies
- ❌ Install unauthorized software

## Summary

**Root Cause**: Corporate Jamf/Zscaler policies blocking disk access

**Best Solution**: Contact IT Support for exception or assistance

**Alternative**: Use personal device (if policy allows)

**Workaround**: Try PhotoRec (may also be blocked)

## Files Created

- `CORPORATE_POLICY_BLOCKING.md`: This guide
- `CRITICAL_SITUATION.md`: Data recovery guide
- `install-data-recovery.sh`: PhotoRec installer (may be blocked)

## Next Steps

1. **Contact IT Support** (recommended)
2. **Try PhotoRec** (may work, may be blocked)
3. **Use personal device** (if policy allows)
4. **Wait for IT assistance** (safest option)

