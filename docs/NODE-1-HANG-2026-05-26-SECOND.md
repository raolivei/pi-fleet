# Node-1 Second Hang - May 26–27, 2026

## Summary

Node-1 hung again **~21:59 EDT May 26** (~3 hours after the first watchdog fix). Manual reboot **~13:26 EDT May 27**. Hardware watchdog did **not** auto-reboot.

## Timeline

| Time (EDT) | Event |
|------------|--------|
| May 26 18:33 | First hang fixed — removed `40-rpi-enable-watchdog.conf` on node-1 |
| May 26 20:37 | Verified node-1 `alive=/dev/watchdog` |
| May 26 21:11+ | Node-3 watchdog logs: `no response from ping (target: 10.0.0.1)` |
| May 26 21:59 | Kubelet last heartbeat; node NotReady ~22:00 |
| May 27 13:26 | Manual reboot; journals from hung boot **not retained** |
| May 27 15:51 | node-2/node-3 RPI drop-in disabled; all nodes verified protected |

## Symptoms

- ICMP to `192.168.2.101` worked; SSH to `10.0.0.1` **connection reset**
- Kubelet stopped posting status; classic “pingable but dead” pattern (same as Feb 2026)

## Why watchdog did not reboot

1. **Ping + load checks insufficient** — partial gigabit failure or daemon still pinging peers while kubelet/SSH frozen.
2. **No application health check** — until May 27 hardening, no `test-binary` for k3s/kubelet/API.
3. **Peer ping does not reboot this node** — node-3 seeing node-1 down does not reboot node-3 (by design).

## Mitigations deployed

- `watchdog-k3s-health.sh` test-binary (k3s, kubelet healthz, :6443)
- Peer-only ping targets (no self-ping)
- `scripts/verify-watchdog.sh` — device ownership + RPI drop-in
- Prometheus: `NodePingableButNotReady`, `WatchdogServiceDown`
- Persistent journald on all nodes for future forensics

## Related

- [NODE-1-HANG-ROOT-CAUSE-2026-05-26.md](NODE-1-HANG-ROOT-CAUSE-2026-05-26.md) — systemd vs daemon device conflict
- [HARDWARE_WATCHDOG.md](HARDWARE_WATCHDOG.md) — operations guide
