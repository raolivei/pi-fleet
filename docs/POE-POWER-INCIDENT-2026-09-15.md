# PoE Power Instability & Journald Persistence Gap - September 15, 2026

## Incident Summary

**Date**: September 15, 2026
**Duration**: ~4 hours, intermittent, across the session
**Nodes affected**: All three (node-1, node-2, node-3) — each went unreachable at least once, at different times
**Power source**: TP-Link TL-SG1008MP, 8-port Gigabit PoE+ switch, 126W total budget, 30W/port (802.3at)
**Impact**: Repeated etcd quorum loss, Vault seal/reset cycles, cluster API unreachable for extended periods, possible node-1 filesystem corruption

## Timeline (condensed)

1. node-1 rejoined the cluster after an earlier unrelated network-config incident (see [NODE-1-HANG-2026-05-26-SECOND.md](NODE-1-HANG-2026-05-26-SECOND.md) for the prior, unrelated hang class).
2. Shortly after, **node-2 hung** (pingable, SSH dead, kubelet unresponsive) — classic "pingable but dead" pattern.
3. Power-cycling node-2 restored quorum. While applying an unrelated CoreDNS fix, **node-3 rebooted** — `journalctl --list-boots` after the reboot showed the current boot only; no shutdown markers, no OOM/panic messages, nothing in the prior boot's journal at all.
4. ICMP timing during this window is the most useful evidence collected (see below): sequences on node-3 showed replies queued for ~27 seconds and then delivered in a burst with near-exactly 1000ms decrements between them (27138ms → 26137ms → 5070ms → 4067ms → 3066ms → 2065ms → 1062ms → 62ms → 4.6ms). This is the signature of a **stalled CPU releasing a backlog of buffered ICMP replies**, not network congestion or packet loss — a switch/link problem drops packets, it does not queue and burst-deliver them a thousand milliseconds apart.
5. Shortly after, **node-1 went unresponsive again**, this time while a `sudo` command returned `Input/output error` — a live filesystem-level failure, not a network timeout. The SSH session dropped immediately after. This is a stronger signal than a hang: it indicates the storage device itself failed to respond to a syscall, consistent with an in-flight write being cut by a power loss.
6. Over the following ~30 minutes, **node-1 and node-3 went down simultaneously** at one point (two of three nodes unreachable at once), then node-2 also dropped briefly. Recovery required multiple manual power-cycles.
7. Once stable, the hardware watchdog was **disabled on all three nodes** at user request — today's failures were power-related brownouts, not application hangs, and the watchdog's 15s auto-reboot was adding an uncontrolled reboot on top of an already uncontrolled power problem rather than helping.

## Why this points at power, not software

- **Three independent nodes**, each on its own SoC/storage/OS, failed in the same hour. A single-node hardware fault (bad NVMe, bad SD, kernel bug) does not explain three separate Pis failing with the same symptom in the same window.
- **The ICMP burst-delivery pattern** on node-3 is specific: it means the kernel's network stack was still alive enough to receive and queue ICMP echo requests, but the scheduler was not running user/kernel code to reply — i.e., the CPU was stalled, not the network. Raspberry Pi 5 firmware throttles (and can eventually reset) when input voltage drops below its 5V/5A rail requirement; this looks exactly like that.
- **node-1's `sudo: Input/output error`** immediately preceding its disconnect is filesystem-level, not SSH-level. A brownout mid-write is a textbook cause.
- **All three nodes share one power source**: the TL-SG1008MP is rated 802.3at (PoE+, 30W/port, 126W total). A Raspberry Pi 5 8GB under sustained load with an NVMe HAT can approach or exceed what a PoE HAT can actually deliver after AC/DC conversion losses — third-party Pi 5 PoE+ HATs commonly under-deliver relative to their rated wattage, and the Pi 5 firmware is strict about brownout detection.

## Why `journalctl -b -1` was empty (and what that does/doesn't mean)

`Storage=persistent` was already configured (per prior session notes, applied to at least node-2 in May 2026) and appeared to be in place. It did not help, for two independent reasons discovered this session:

1. **A real config bug**: Raspberry Pi OS ships `/usr/lib/systemd/journald.conf.d/40-rpi-volatile-storage.conf`, which sets `Storage=volatile` and — because later-loaded drop-ins win — **silently overrides** `Storage=persistent` in `/etc/systemd/journald.conf`. This exists to spare SD cards from write wear; these nodes boot from NVMe, so the override is wrong for this hardware, not a deliberate choice. Confirmed via `systemd-analyze cat-config systemd/journald.conf`, which showed three merged `[Journal]` blocks with the RPi one last. This is the same category of bug already documented for the hardware watchdog (`40-rpi-enable-watchdog.conf`, see [NODE-1-HANG-ROOT-CAUSE-2026-05-26.md](NODE-1-HANG-ROOT-CAUSE-2026-05-26.md)) — an RPi-OS default that assumes SD-card boot media on hardware that doesn't use it.
2. **A hardware ceiling that config cannot fix**: even with `Storage=persistent` genuinely active, journald does not fsync every line. An abrupt power cut can lose the last few seconds of buffered log lines, and can leave the currently-active journal file in a state journald considers corrupt, in which case it starts a fresh file on the next boot rather than risk reading a torn write — discarding exactly the segment that would explain the crash. Persistent storage protects against clean reboots, service restarts, and watchdog-triggered resets (anything with a shutdown sequence). It does not protect against the power simply disappearing mid-write.

## Fix applied

- **`ansible/playbooks/configure-persistent-journal.yml`** (new) — standalone, idempotent playbook: removes the RPi volatile-storage drop-in if present, ensures `/var/log/journal` exists with correct ownership (required before `Storage=persistent` takes effect — the directory did not previously exist on any of the three nodes), sets `Storage=persistent` / `SystemMaxUse=500M` / `MaxRetentionSec=7day`, flushes the runtime journal into persistent storage, and **verifies** via `journalctl --header` that the active file path is under `/var/log/journal` rather than `/run/log/journal` — the previous approach (`setup-hardware-watchdog.yml`) set the config but never verified it took effect, which is exactly how this went unnoticed since May.
- Applied live to node-2 and node-3 (confirmed: `File path: /var/log/journal/<machine-id>/system.journal`). **Not yet applied to node-1**, which was down for the remainder of the session — run `ansible-playbook playbooks/configure-persistent-journal.yml --limit node-1` once it's confirmed stable.
- Hardware watchdog disabled on all three nodes pending resolution of the power issue (re-enable via `ansible-playbook playbooks/setup-hardware-watchdog.yml` once resolved).

## Open / recommended follow-ups

1. **Verify node-1's filesystem integrity** once it's reachable: `sudo dmesg | grep -iE "error|i/o|ext4|nvme"`, and consider `fsck` if the node is not urgently needed. Repeated brownouts on storage that was mid-write are a plausible corruption vector; a full reinstall may be safer than repeated recovery attempts if errors are found.
2. **Confirm the PoE HAT model** on each node and its actual (not rated) power delivery under load — official Raspberry Pi PoE+ HAT vs. third-party makes a material difference here.
3. **Consider moving one or more nodes off PoE** to a dedicated 5V/5A (27W) USB-C supply, keeping the Ethernet-only (data) benefit of the PoE switch without its power budget constraint, as a way to isolate whether PoE delivery is specifically the cause.
4. **If keeping PoE**, verify the switch's actual per-port and total draw against its rated 126W under full 3-node load (NVMe + sustained CPU), ideally via the switch's own management interface if it exposes PoE power monitoring.
5. Re-enable the hardware watchdog once the power issue is resolved — it remains valuable protection against genuine software hangs, just not against brownouts.

## Related

- [NODE-1-HANG-ROOT-CAUSE-2026-05-26.md](NODE-1-HANG-ROOT-CAUSE-2026-05-26.md) — the systemd-vs-daemon watchdog device conflict (different root cause, same "RPi default assumes different hardware" pattern)
- [NODE-1-HANG-2026-05-26-SECOND.md](NODE-1-HANG-2026-05-26-SECOND.md) — earlier "pingable but dead" hang, unrelated to power
- [HARDWARE_WATCHDOG.md](HARDWARE_WATCHDOG.md) — watchdog operations guide
- `ansible/playbooks/configure-persistent-journal.yml` — the fix
