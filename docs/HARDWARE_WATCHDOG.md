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
| `ping` | 10.0.0.x | Check cluster node connectivity via gigabit |
| `pidfile` | /var/run/k3s.pid | Verify k3s service is running |
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

### Service Status
```bash
ssh raolivei@10.0.0.1 "systemctl status watchdog"
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
