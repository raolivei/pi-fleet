# Eldertree access: document DNS vs hosts-only, remove WireGuard from path

**GitHub issue:** [#125 Eldertree access: document DNS vs hosts-only, remove WireGuard from path](https://github.com/raolivei/pi-fleet/issues/125)

---

## Goal

Document both DNS (192.168.2.201 + 1.1.1.1) and hosts-only eldertree.local access in TAILSCALE.md, add a corporate-VPN note for the hosts-only path, and remove WireGuard from the Eldertree access path (Tailscale only).

## Context

- **DNS path:** With a DNS resolver in place, Mac DNS can be 192.168.2.201 (Pi-hole) and 1.1.1.1. Pi-hole resolves `*.eldertree.local`; no `/etc/hosts` block needed for services.
- **Hosts-only path:** When DNS cannot be changed (e.g. corporate AWS VPN conflicts), use Tailscale + full `/etc/hosts` block only; Mac DNS stays as-is.
- **WireGuard:** Eldertree access uses Tailscale only; WireGuard is not documented as an option for that path.

## Tasks

- [x] **TAILSCALE.md "Access all services from your Mac":** Add Option A (DNS: 192.168.2.201 + 1.1.1.1) and Option B (hosts-only + corporate-VPN note). *(Done)*
- [x] **eldertree-local-hosts-block.txt:** Add comment that block is optional when using Pi-hole + 1.1.1.1; required when can't change DNS. *(Done)*
- [x] **TAILSCALE.md "VPN and eldertree.local access":** Remove WireGuard bullet and Related Documentation link to WireGuard; state Tailscale-only. *(Done)*
- [x] **TAILSCALE.md "Current state" / design:** Clarify DNS vs hosts-only where Pi-hole is mentioned. *(Done)*

## Result

- Docs present two access options: DNS (192.168.2.201 + 1.1.1.1) or hosts-only (/etc/hosts block).
- WireGuard removed from Eldertree access path in docs (repo WireGuard assets unchanged).
- Corporate-VPN callout for hosts-only path.

## Plan reference

`~/.cursor/plans/dns-free_access,_no_wireguard_222ba0b1.plan.md`
