# Hardware Watchdog Setup

## Overview

Hardware watchdog monitors the system and automatically reboots if it becomes unresponsive. This protects against node freezes where the system is still reachable (pingable) but cannot respond to application requests.

## Problem Context

Node-1 froze on Feb 13-17, 2026:
- Kubelet stopped responding for 4+ days
- System remained pingable (ICMP worked)
- No automatic recovery occurred
- Required manual power cycle to recover

See [GitHub Issue #153](https://github.com/raolivei/pi-fleet/issues/153).

## How It Works

### Watchdog Daemon

The BCM2835 watchdog (Raspberry Pi hardware) monitors system health:
1. Daemon periodically "kicks" the watchdog (resets timeout)
2. If daemon stops (system frozen), watchdog counter runs down
3. When counter reaches zero, hardware forces reboot
4. System recovers within seconds (vs days with manual intervention)

### Boot Loop Protection

To prevent infinite reboot loops, a boot guard tracks consecutive reboots:
1. On boot, `watchdog-boot-guard.service` runs before watchdog daemon
2. Reads boot counter from `/var/lib/watchdog-boot-count`
3. If counter >= 5: disables watchdog, logs critical alert, requires manual intervention
4. If counter < 5: increments counter, allows boot to continue
5. After 10 minutes uptime: timer resets counter to 0 (successful boot)
## Configuration

### Parameters

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `watchdog-timeout` | 15s | Hardware timeout before forced reboot |
| `interval` | 5s | How often daemon kicks watchdog |
| `max-load-1` | 24 | Reboot if 1-min load avg exceeds this |
| `ping` | peer 10.0.0.x only | Each node pings **other** nodes (not self); reboot if **all** peers unreachable |
| `test-binary` | `/usr/local/bin/watchdog-k3s-health.sh` | k3s active, kubelet `/healthz`, API `:6443` |
| `watchdog_max_boot_attempts` | 5 | Max consecutive reboots before disabling watchdog |
| `watchdog_successful_boot_time` | 600s | Time node must stay up to reset boot counter |

### File Location

`/etc/watchdog.conf`

## Deployment

### Single Node Test
```bash
cd ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/setup-hardware-watchdog.yml \
  --limit node-3
```

### All Nodes
```bash
cd ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/setup-hardware-watchdog.yml
```

## Verification

### All nodes (from laptop)
```bash
./scripts/verify-watchdog.sh
```
Checks: service active, RPI drop-in absent, `watchdog` process holds `/dev/watchdog` (uses WiFi `192.168.2.10x` if gigabit SSH fails).

### Service Status
```bash
ssh raolivei@192.168.2.101 "systemctl status watchdog"
sudo lsof /dev/watchdog   # must show watchdog daemon, not wd_keepalive alone
```

### Logs
```bash
ssh raolivei@10.0.0.1 "journalctl -u watchdog -f"
```

### Configuration Check
```bash
ssh raolivei@10.0.0.1 "cat /etc/watchdog.conf | grep -v '^#'"
```

## Monitoring

### Prometheus Alert

Alert fires when node reboots unexpectedly:
```
NodeWatchdogReboot: "Node X rebooted"
```

Check AlertManager at `alertmanager.eldertree.local`.

### Manual Check

Check for unexpected reboots:
```bash
ssh raolivei@10.0.0.1 "uptime"
# Compare with other nodes
```

## Troubleshooting

### Boot Loop (5 Reboots Limit Reached)

If watchdog disabled after 5 consecutive reboots:

1. **Check boot counter**
   ```bash
   ssh raolivei@10.0.0.1 "cat /var/lib/watchdog-boot-count"
   ```

2. **Check boot guard logs**
   ```bash
   ssh raolivei@10.0.0.1 "journalctl -u watchdog-boot-guard -n 50"
   ```

3. **Investigate root cause**
   - Check system logs: `journalctl -b -n 100`
   - Check k3s status: `systemctl status k3s`
   - Check network connectivity to other nodes

4. **Reset counter and re-enable watchdog**
   ```bash
   ssh raolivei@10.0.0.1 "echo 0 | sudo tee /var/lib/watchdog-boot-count"
   ssh raolivei@10.0.0.1 "sudo systemctl enable watchdog && sudo systemctl start watchdog"
   ```
### False Positive Reboots

If nodes reboot unexpectedly:

1. **Check load average**
   ```bash
   ssh raolivei@10.0.0.1 "uptime"
   ```
   If > 24, watchdog is protecting against system overload. This is working as designed.

2. **Check k3s service**
   ```bash
   ssh raolivei@10.0.0.1 "systemctl status k3s"
   ```
   If k3s crashed, watchdog detected it. Investigate k3s logs.

3. **Check network connectivity**
   ```bash
   ssh raolivei@10.0.0.1 "ping -c 1 10.0.0.1"
   ```
   If network unavailable, watchdog triggers reboot. Check eth0 connectivity.

4. **Adjust Thresholds**

   Edit `ansible/group_vars/all.yml`:
   ```yaml
   watchdog_timeout: 30  # Increase from 15s
   watchdog_max_load: 32  # Increase from 24
   ```
   
   Reapply playbook to all nodes.

### Service Not Starting

```bash
ssh raolivei@10.0.0.1 "journalctl -u watchdog -n 50"
```

Common issues:
- Watchdog device not available: `/dev/watchdog` missing (driver not loaded)
- Permission denied: Check file ownership of `/etc/watchdog.conf`

### Watchdog Didn't Prevent Hang

**Symptoms**: Node hung and required manual reboot, even though watchdog service was supposed to be running.

**Diagnosis**:

1. Check if watchdog was actually running during hang:
   ```bash
   ssh raolivei@10.0.0.X "journalctl -u watchdog --since '<hang-time>'"
   ```

2. Check what caused the hang (look in previous boot logs):
   ```bash
   ssh raolivei@10.0.0.X "journalctl --boot=-1 | grep -i 'oom\|panic\|hang\|lockup\|watchdog'"
   ```

3. Check boot counter (if ≥5, watchdog auto-disabled):
   ```bash
   ssh raolivei@10.0.0.X "cat /var/lib/watchdog-boot-count"
   ```

4. Verify watchdog was deployed to the node:
   ```bash
   ssh raolivei@10.0.0.X "systemctl status watchdog"
   ssh raolivei@10.0.0.X "cat /etc/watchdog.conf"
   ```

**Possible Causes**:

- **Boot loop protection triggered**: Watchdog disabled after 5 consecutive reboots
  - **Fix**: Reset counter: `ssh raolivei@10.0.0.X "echo 0 | sudo tee /var/lib/watchdog-boot-count"`
  
- **Watchdog daemon crashed before hang**: Service stopped unexpectedly
  - **Fix**: Check `journalctl -u watchdog` for crash logs. Add systemd restart policy if needed.
  
- **Hang type not covered**: Kernel deadlock, hardware issue, or hang that keeps load low and network up
  - **Explanation**: Watchdog only triggers on high load (>24) or network failure. Silent hangs may not be detected.
  - **Mitigation**: Consider lowering max-load threshold or adding application-level health checks.
  
- **Network isolation**: If all ping targets (10.0.0.1-3) are unreachable, watchdog detects as local hang
  - **Explanation**: If gigabit network is down, watchdog can't verify cluster health
  - **Check**: Verify eth0 connectivity to other nodes

- **Watchdog not deployed**: Playbook may not have run on this specific node
  - **Fix**: Run `ansible-playbook playbooks/setup-hardware-watchdog.yml --limit node-X`

**Resolution Steps**:

1. Verify watchdog is installed and running:
   ```bash
   ssh raolivei@10.0.0.X "systemctl status watchdog"
   ```

2. Check and reset boot counter if needed:
   ```bash
   ssh raolivei@10.0.0.X "cat /var/lib/watchdog-boot-count"
   ssh raolivei@10.0.0.X "echo 0 | sudo tee /var/lib/watchdog-boot-count"
   ```

3. Review configuration:
   ```bash
   ssh raolivei@10.0.0.X "cat /etc/watchdog.conf | grep -v '^#' | grep -v '^$'"
   ```

4. Check for watchdog activity in logs:
   ```bash
   ssh raolivei@10.0.0.X "journalctl -u watchdog -f"
   ```

5. If watchdog not deployed, run Ansible playbook:
   ```bash
   cd ansible
   ansible-playbook -i inventory/hosts.yml playbooks/setup-hardware-watchdog.yml --limit node-X
   ```

6. Test watchdog is responding:
   ```bash
   ssh raolivei@10.0.0.X "sudo systemctl restart watchdog && journalctl -u watchdog -f"
   ```

**Verification**:

Use the verification script to check all nodes:
```bash
./scripts/verify-watchdog.sh
```

Expected output for healthy node:
```
--- node-1 (10.0.0.1) ---
✓ Service: running
Boot counter: 0
Watchdog restarts (24h): 0
System boot time: 2026-05-26 18:33:15
Watchdog timeout: 15s
```

## Disabling

To disable watchdog:
```bash
ssh raolivei@10.0.0.1 "sudo systemctl stop watchdog && sudo systemctl disable watchdog"
```

To re-enable:
```bash
cd ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/setup-hardware-watchdog.yml
```

## References

- [Watchdog Documentation](https://linux.die.net/man/5/watchdog.conf)
- [Raspberry Pi Hardware Watchdog](https://www.raspberrypi.org/documentation/)
- [BCM2835 Watchdog](https://github.com/raspberrypi/linux/blob/rpi-5.10.y/drivers/watchdog/bcm2835_wdt.c)
- [pi-fleet Issue #153](https://github.com/raolivei/pi-fleet/issues/153)
