# ARCHIVED — Visage connectivity doc (2026-04)

**Visage** was decommissioned. Use [TAILSCALE.md](../TAILSCALE.md) and [eldertree-local-hosts-block.txt](../eldertree-local-hosts-block.txt) for general `*.eldertree.local` access.

---

# Troubleshooting: Unable to connect to *.eldertree.local (historical)

When the browser shows **"No available server"**, **"Unable to connect"**, or **"Server not found"** for `https://grafana.eldertree.local` or any `*.eldertree.local` URL, the cause is usually one of two things:

1. **DNS** — The hostname doesn't resolve. Your Mac needs either Pi-hole (192.168.2.201) as DNS or a `/etc/hosts` block so `*.eldertree.local` points at the Traefik IP.
2. **Routing** — The Traefik IP (e.g. 192.168.2.200) is unreachable. When you're off the Eldertree LAN you need Tailscale with **Accept Routes** so traffic can reach the cluster.

See [TAILSCALE.md](../TAILSCALE.md) for the current checklist.
