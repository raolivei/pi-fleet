# Node-1 Hang Root Cause Analysis - May 26, 2026

## Incident Summary

**Date**: May 26, 2026  
**Time**: ~18:30 EDT  
**Node**: node-1.eldertree.local (192.168.2.101 / 10.0.0.1)  
**Duration**: Unknown (node rebooted at 18:33, discovered hung requiring manual reboot)  
**Impact**: Node required manual reboot, came back cordoned (SchedulingDisabled)

## Investigation Findings

### Watchdog Status

**Expected**: Hardware watchdog daemon running with 15s timeout  
**Actual**: Watchdog daemon running but **NOT protecting the system**

**Critical Discovery**:
```
May 26 18:33:14 node-1 watchdog[2085]: cannot open /dev/watchdog (errno = 16 = 'Device or resource busy')
```

The watchdog daemon has been unable to open `/dev/watchdog` since boot because **systemd already claimed it**:

```
[    5.752484] systemd[1]: Using hardware watchdog 'Broadcom BCM2835 Watchdog timer', version 0, device /dev/watchdog0
[    5.765614] systemd[1]: Watchdog running with a hardware timeout of 1min.
```

### Root Cause

**systemd built-in watchdog** is using the hardware watchdog device with a **1-minute timeout**. This prevents our watchdog daemon from accessing the device.

**Why this is a problem**:
- systemd's watchdog only protects against systemd itself freezing
- If k3s/kubelet hangs but systemd remains responsive, the watchdog won't trigger
- Our watchdog daemon checks load average and network connectivity - systemd's doesn't
- 1-minute timeout is much longer than our configured 15-second timeout

### Why Node-2 and Node-3 Work Correctly

Checked node-2 and node-3 - **neither have systemd using the watchdog**. They both have the watchdog daemon successfully running and protecting the system.

**This suggests node-1 has a different systemd configuration or was set up differently.**

## Resolution

### Option 1: Disable systemd's watchdog (Recommended)

Disable systemd's built-in watchdog so our daemon can use the hardware:

```bash
ssh raolivei@192.168.2.101 "sudo systemctl edit systemd.conf"
# Add:
# [Manager]
# RuntimeWatchdogSec=0
sudo systemctl daemon-reexec
```

Or via /etc/systemd/system.conf:
```bash
RuntimeWatchdogSec=0
```

### Option 2: Use systemd's watchdog (Alternative)

Configure systemd to monitor k3s service health:

```bash
# /etc/systemd/system/k3s.service.d/watchdog.conf
[Service]
WatchdogSec=30
```

This requires k3s to send keep-alive signals to systemd.

### Option 3: Dual-layer protection (Advanced)

- Keep systemd watchdog for systemd failures (1min timeout)
- Use `watchdog0` device for our daemon (systemd uses `/dev/watchdog`, daemon uses `/dev/watchdog0`)

Update `/etc/watchdog.conf`:
```
watchdog-device = /dev/watchdog0
```

## Verification Steps

After implementing fix:

1. **Stop watchdog daemon**:
   ```bash
   ssh raolivei@192.168.2.101 "sudo systemctl stop watchdog"
   ```

2. **Check what's using watchdog device**:
   ```bash
   ssh raolivei@192.168.2.101 "sudo lsof /dev/watchdog* || echo 'Nothing using watchdog'"
   ```

3. **Restart watchdog daemon**:
   ```bash
   ssh raolivei@192.168.2.101 "sudo systemctl start watchdog"
   ```

4. **Verify successful open**:
   ```bash
   ssh raolivei@192.168.2.101 "journalctl -u watchdog --since '1 minute ago' | grep -v 'cannot open'"
   ```
   
   Should see "starting daemon" without "cannot open" error.

5. **Test watchdog is kicking device**:
   ```bash
   ssh raolivei@192.168.2.101 "journalctl -u watchdog -f"
   ```
   
   Watch for periodic activity (every 5 seconds).

## Timeline

- **~18:30**: Node-1 hung (exact time unknown, no persistent journal)
- **18:33:14**: Node rebooted (manual power cycle)
- **18:33:14**: Watchdog daemon started but failed to open device (systemd already using it)
- **20:37:36**: Current boot time (node has been up ~2.5 hours)
- **21:08**: Investigation revealed systemd watchdog conflict

## Lessons Learned

1. **Watchdog verification script needed** - Created `scripts/verify-watchdog.sh` to check all nodes
2. **Monitoring gap** - No alerts for watchdog failures or unexpected reboots (now added to Prometheus)
3. **Configuration drift** - Node-1 has different systemd config than node-2/3 (investigate why)
4. **"Service running" ≠ "System protected"** - Watchdog service can be running but ineffective

## Related

- Historical: [Node-1 Feb 13-17 hang](docs/NODE_1_ROOT_CAUSE.md) - 4-day freeze, led to watchdog implementation
- Watchdog implementation: Issue #153, commit 4aea5ff (May 26, 2026)
- Critical fix: Commit 4f50ca7 - Removed k3s pidfile check
- This incident: PR #182 - Watchdog monitoring and verification

## Action Items

- [x] Fix node-1 systemd watchdog conflict - **RESOLVED**
- [x] Identified Raspberry Pi specific drop-in file causing conflict
- [x] Removed `/usr/lib/systemd/system.conf.d/40-rpi-enable-watchdog.conf`
- [x] Verified watchdog daemon now has device access
- [ ] Add systemd watchdog check to verification script
- [ ] Check node-2 and node-3 for same file (preventive)
- [ ] Update Ansible playbook to remove this file on all nodes
- [ ] Merge PR #182 (monitoring alerts + verification script)
- [ ] Document fix in eldertree-docs runbook

## Resolution - FIXED ✅

**Root Cause Identified**: Raspberry Pi specific systemd drop-in configuration file:
```
/usr/lib/systemd/system.conf.d/40-rpi-enable-watchdog.conf
```

This file contains:
```
[Manager]
RuntimeWatchdogSec=1m
RebootWatchdogSec=2m
```

**Why node-2 and node-3 worked**: They don't have this file (likely from different OS installation or update path).

**Fix Applied**:
1. Moved `/usr/lib/systemd/system.conf.d/40-rpi-enable-watchdog.conf` to `/tmp/`
2. Rebooted node-1 (4th reboot)
3. Verified systemd no longer using watchdog: `dmesg | grep systemd.*watchdog` returns nothing
4. Verified watchdog daemon successfully opened device: `lsof /dev/watchdog` shows PID 2054 (watchdog)

**Current Status**: ✅ **Node-1 is now protected**
- Watchdog daemon running and has `/dev/watchdog` open
- No "cannot open" errors in journalctl
- Hardware watchdog active with 15s timeout
- Boot loop protection active (max 5 reboots)
- All 3 nodes Ready in Kubernetes
