# Troubleshooting: Unable to connect to \*.eldertree.local (grafana, visage, etc.)

When the browser shows **"No available server"**, **"Unable to connect"**, or **"Server not found"** for `https://grafana.eldertree.local`, `https://visage.eldertree.local`, or any `*.eldertree.local` URL, the cause is usually one of two things:

1. **DNS** — The hostname doesn't resolve. Your Mac needs either Pi-hole (192.168.2.201) as DNS or a `/etc/hosts` block so `*.eldertree.local` points at the Traefik IP.
2. **Routing** — The Traefik IP (e.g. 192.168.2.200) is unreachable. When you're off the Eldertree LAN you need Tailscale with **Accept Routes** so traffic can reach the cluster.

Work through the checklist below.

**On the same LAN as Eldertree (e.g. 192.168.2.x)?** You don’t need Tailscale. You only need the hostname to resolve (Pi-hole or `/etc/hosts`) and, on macOS, Local Network permission for the browser. Use the steps below and skip the Tailscale section.

## 1. Resolve the hostname (e.g. grafana.eldertree.local or visage.eldertree.local)

Your Mac must resolve the `*.eldertree.local` hostname to the Traefik LoadBalancer IP.

**Option A — You use Pi-hole (192.168.2.201) as DNS**

- In **System Settings → Network → Wi‑Fi (or Ethernet) → DNS**, ensure **192.168.2.201** and **1.1.1.1** are listed.
- Then `grafana.eldertree.local`, `visage.eldertree.local`, etc. should resolve via Pi-hole (no `/etc/hosts` needed).

**Option B — Hosts-only (e.g. can’t or don’t want to change DNS)**

- Get Traefik EXTERNAL-IP (from a machine that can run kubectl against Eldertree):
  ```bash
  kubectl get svc traefik -n kube-system
  ```
- Copy [eldertree-local-hosts-block.txt](eldertree-local-hosts-block.txt), replace `TRAEFIK_LB_IP` with that IP (e.g. `10.0.0.3` or `192.168.2.200`), and append the block to `/etc/hosts`.

**Verify resolution**

```bash
ping -c 1 grafana.eldertree.local
# or
dscacheutil -q host -a name grafana.eldertree.local
```

You should see the Traefik IP. If ping fails with "cannot resolve", fix DNS or `/etc/hosts` first.

## 2. Tailscale (only when you’re off the Eldertree LAN)

If you’re **not** on the same network as the cluster (e.g. away from home), you need Tailscale so traffic can reach the Eldertree subnets:

- Tailscale app running and **Accept Routes** enabled (Tailscale menu → Preferences).
- Then resolution (Pi-hole or `/etc/hosts`) still required as above; Pi-hole must be reachable (e.g. via Tailscale or VPN) if you use it for DNS.

If you’re on the Eldertree LAN, you can skip this.

## 3. Firefox: Local Network permission (macOS)

macOS can block browsers from reaching local network hosts (including `.local`). The Firefox error often suggests this.

- Open **System Settings → Privacy & Security → Local Network**.
- Find **Firefox** in the list and ensure it is **on** (allowed to access the local network).

Then try `https://grafana.eldertree.local` or `https://visage.eldertree.local` again.

## 4. Quick connectivity test

From Terminal (bypasses browser):

```bash
curl -k -o /dev/null -w "%{http_code}\n" https://grafana.eldertree.local
```

- If you get a numeric code (e.g. 200), the service is reachable; the problem is likely browser or Local Network permission.
- If connection times out or "Could not resolve host", fix resolution (DNS or `/etc/hosts`). If you’re off-LAN, also ensure Tailscale is on with Accept Routes.

## Reference

- Full access flow: [TAILSCALE.md — Access all services from your Mac](TAILSCALE.md#access-all-services-from-your-mac)
- Hosts block: [eldertree-local-hosts-block.txt](eldertree-local-hosts-block.txt)
