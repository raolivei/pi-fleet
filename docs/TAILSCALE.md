# Tailscale VPN - HA Subnet Routing

Tailscale provides secure, zero-config VPN access to the eldertree cluster from anywhere with automatic high-availability failover.

**Current state:** Tailscale is the intended VPN for accessing **all** Eldertree services (vault, grafana, visage, swimto, minio, etc.) from your Mac. The Mac is never on the gigabit network, so Tailscale (with Accept Routes) plus either **DNS** (192.168.2.201 + 1.1.1.1) or the full **/etc/hosts** block is the canonical path. Use DNS when you can; if you cannot change DNS (e.g. corporate VPN conflicts), use only the `/etc/hosts` block. Tailscale is enabled when `tailscaled` is not in `disabled_services` in ansible `group_vars/all.yml`. If you see routing conflicts when the Mac is on the same LAN (192.168.2.x), you can temporarily add `tailscaled` back to `disabled_services` while at home and use Pi-hole + Traefik (192.168.2.200) directly. See [Enabling Tailscale](#enabling-tailscale) and [Access all services from your Mac](#access-all-services-from-your-mac) below.

## Overview

All 3 cluster nodes are configured as Tailscale subnet routers, advertising the home LAN and Kubernetes networks. If any node goes down, traffic automatically routes through another node (~15 seconds failover).

## Node Configuration

| Node   | Tailscale IP   | LAN IP        | Status        |
| ------ | -------------- | ------------- | ------------- |
| node-1 | 100.86.241.124 | 192.168.2.101 | Subnet Router |
| node-2 | 100.116.185.57 | 192.168.2.102 | Subnet Router |
| node-3 | 100.104.30.105 | 192.168.2.103 | Subnet Router |

## Advertised Subnets

| Subnet         | Description                                 |
| -------------- | ------------------------------------------- |
| 192.168.2.0/24 | Home LAN                                    |
| 10.0.0.0/24    | Gigabit network (Traefik LB, e.g. 10.0.0.3) |

> **Note:** Kubernetes CIDRs (10.42.0.0/16, 10.43.0.0/16) are intentionally NOT advertised. Tailscale adds policy routes (table 52) for every advertised subnet, which hijacks pod/service traffic away from Flannel/cni0 and breaks k3s networking. All services are accessed via Traefik ingress instead of direct pod IPs.

### Node Tailscale settings

- `--netfilter-mode=off` — UFW + kube-router already manage iptables; Tailscale's ts-input/ts-forward chains conflict with k3s FORWARD rules.
- `--accept-routes=false` — Only Mac/mobile clients need accept-routes. On subnet router nodes sharing the same LAN, accepting routes creates table 52 entries that hijack local traffic through tailscale0.
- `--accept-dns=false` — **Critical.** Tailscale's MagicDNS rewrites `/etc/resolv.conf` to use `100.100.100.100` and adds `tailb05d7e.ts.net` as a search domain. CoreDNS inherits this via `forward . /etc/resolv.conf`, routing ALL cluster DNS through Tailscale's proxy. This causes intermittent DNS failures, pod health probe timeouts, and cluster-wide restart cascades. A dedicated `/etc/rancher/k3s/resolv.conf` is also deployed as a safety net (configured via `resolv-conf` in k3s config).

## Client Setup

### macOS

1. Download Tailscale from https://tailscale.com/download/mac
2. Install and login with the same account used for the cluster
3. Click the Tailscale icon in menu bar → **Preferences**
4. Enable **"Accept Routes"** (critical for subnet access)
5. Verify connection: `tailscale status`

### iOS/iPadOS

1. Install Tailscale from App Store
2. Login with same account
3. Go to Settings → Tailscale → Enable **"Allow local network access"**
4. The subnets will be automatically accepted

### Linux

```bash
# Install
curl -fsSL https://tailscale.com/install.sh | sh

# Connect with subnet routing enabled
sudo tailscale up --accept-routes

# Verify
tailscale status
```

## Access all services from your Mac

This is the **canonical way** to reach every `*.eldertree.local` service (vault, grafana, visage, swimto, minio, etc.) from your Mac when it is not on the Eldertree LAN.

### Prerequisites

- Tailscale enabled on cluster nodes (see [Enabling Tailscale](#enabling-tailscale)).
- Mac has Tailscale installed and **Accept Routes** enabled (Tailscale menu → Preferences).

### Choose how to resolve eldertree.local

**Option A — DNS (when you can use custom DNS)**

If you have a DNS resolver and can set your Mac’s DNS to **192.168.2.201** (Pi-hole) and **1.1.1.1**, Pi-hole resolves `*.eldertree.local` to the Traefik VIP. You don’t need the `/etc/hosts` block for services; Tailscale + Accept Routes still required for routing when off-LAN. Set DNS in System Settings → Network → Wi-Fi/Ethernet → DNS (192.168.2.201, 1.1.1.1).

**Option B — Hosts-only (when you cannot change DNS)**

You do **not** need to change your Mac’s DNS. Use Tailscale + the full `/etc/hosts` block only. `/etc/hosts` is used before DNS, so only `*.eldertree.local` come from it; everything else (company resources, internet) keeps your current DNS. **If you use a corporate VPN (e.g. AWS VPN) that conflicts with custom DNS, do not change system DNS; use only Tailscale + the `/etc/hosts` block.**

### Steps

1. **Get the Traefik LoadBalancer IP** (needed for hosts-only, or to verify Pi-hole is pointing at the right place)

   ```bash
   kubectl get svc traefik -n kube-system
   ```

   Use the **EXTERNAL-IP** (e.g. `192.168.2.200` on WiFi, or `10.0.0.3` on gigabit).

2. **Resolve eldertree.local**
   - **DNS path:** Set Mac DNS to 192.168.2.201 and 1.1.1.1 (Pi-hole resolves `*.eldertree.local`).
   - **Hosts-only path:** Copy the block from [eldertree-local-hosts-block.txt](eldertree-local-hosts-block.txt), replace `TRAEFIK_LB_IP` with the Traefik EXTERNAL-IP from step 1, and append to `/etc/hosts`. That file is the single source of truth for all `*.eldertree.local` hostnames (vault, grafana, prometheus, pihole, visage, minio, swimto, canopy, pitanga, pushgateway, flux-ui, alertmanager, docs, journey, nima, and node-1/2/3).

3. **Use services**

   Open `https://<service>.eldertree.local` in the browser (e.g. `https://vault.eldertree.local`, `https://visage.eldertree.local`). Accept self-signed certificate warnings when prompted.

### Quick checks

See [Verify Connectivity](#verify-connectivity) for `tailscale status`, ping, and `curl -k` examples.

## Verify Connectivity

```bash
# Check Tailscale status
tailscale status

# Ping cluster nodes via Tailscale IPs (always works)
ping 100.86.241.124   # node-1
ping 100.116.185.57   # node-2
ping 100.104.30.105   # node-3

# Access Kubernetes API
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes

# SSH to nodes
ssh raolivei@192.168.2.101

# Access services (after following "Access all services from your Mac" above)
curl -k https://vault.eldertree.local
curl -k https://grafana.eldertree.local
```

## Remote Access (Outside Home Network)

When accessing the cluster from outside your home network (mobile LTE, coffee shop, etc.), use the Tailscale direct IPs instead of LAN IPs.

### kubeconfig for Remote Access

A separate kubeconfig is available for remote access:

| Location   | kubeconfig                        | API Server          |
| ---------- | --------------------------------- | ------------------- |
| Home (LAN) | `~/.kube/config-eldertree`        | 192.168.2.100:6443  |
| Remote     | `~/.kube/config-eldertree-remote` | 100.86.241.124:6443 |

**Usage:**

```bash
# When at home
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes

# When remote (mobile, travel, etc.)
export KUBECONFIG=~/.kube/config-eldertree-remote
kubectl get nodes
```

### SSH from Remote

Use Tailscale IPs for SSH when remote:

```bash
# Via Tailscale IPs (works from anywhere)
ssh raolivei@100.86.241.124  # node-1
ssh raolivei@100.116.185.57  # node-2
ssh raolivei@100.104.30.105  # node-3
```

### Lens IDE Configuration

For guaranteed cluster access in Lens regardless of WiFi VIP issues:

1. **Install Tailscale on your Mac** (if not already): https://tailscale.com/download/mac
2. **Enable Accept Routes** in Tailscale preferences
3. **Add the remote kubeconfig to Lens:**
   - Open Lens → File → Add Cluster (or Cmd+Shift+A)
   - Select "Add from kubeconfig file"
   - Choose `~/.kube/config-eldertree-remote`
   - Name it "eldertree-remote" to distinguish from the LAN config

**Why use the remote config?**
- The default `config-eldertree` uses the kube-vip WiFi VIP (192.168.2.100)
- If the VIP leader node's WiFi fails, the VIP becomes unreachable
- The remote config uses Tailscale (100.86.241.124) which is more reliable

**Limitation:** The remote config points only to node-1. If node-1 is completely down, you'll need to manually edit the kubeconfig to use node-2 (100.116.185.57) or node-3 (100.104.30.105).

### Create Remote kubeconfig (if needed)

If `~/.kube/config-eldertree-remote` doesn't exist:

```bash
CLIENT_CERT=$(grep client-certificate-data ~/.kube/config-eldertree | awk '{print $2}')
CLIENT_KEY=$(grep client-key-data ~/.kube/config-eldertree | awk '{print $2}')

cat > ~/.kube/config-eldertree-remote << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://100.86.241.124:6443
  name: eldertree-remote
contexts:
- context:
    cluster: eldertree-remote
    user: eldertree-admin
  name: eldertree-remote
current-context: eldertree-remote
users:
- name: eldertree-admin
  user:
    client-certificate-data: ${CLIENT_CERT}
    client-key-data: ${CLIENT_KEY}
EOF
```

> **Note:** Uses `insecure-skip-tls-verify` because the cluster TLS cert doesn't include Tailscale IPs.

## Administration

### Check Node Status

```bash
# From any node
ssh raolivei@192.168.2.101 "tailscale status"

# View advertised routes
ssh raolivei@192.168.2.101 "tailscale status --json | jq '.Self.AllowedIPs'"
```

### Re-run Ansible Playbook

If you need to reconfigure or add new nodes:

```bash
cd /path/to/pi-fleet/ansible

# Get auth key from Vault (use root token)
export KUBECONFIG=~/.kube/config-eldertree
ROOT_TOKEN=$(kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.ROOT_TOKEN}' | base64 -d)
AUTH_KEY=$(kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault kv get -field=auth-key secret/pi-fleet/tailscale")

# Run playbook
ansible-playbook -i inventory/hosts.yml playbooks/install-tailscale.yml \
  -e "tailscale_auth_key=$AUTH_KEY"
```

### Generate New Auth Key

If the auth key expires or you need a new one:

1. Go to https://login.tailscale.com/admin/settings/keys
2. Generate new key with:
   - ✅ Reusable
   - ✅ Pre-authorized
   - Tag: `tag:subnet-router`
3. Update Vault:
   ```bash
   kubectl exec -n vault vault-0 -- vault kv put secret/pi-fleet/tailscale \
     auth-key="tskey-auth-NEW_KEY_HERE"
   ```

## Tailscale ACL Configuration

The Tailscale ACL (Access Control List) is configured in the Tailscale admin console:

```json
{
  "tagOwners": {
    "tag:subnet-router": ["autogroup:admin"]
  },
  "autoApprovers": {
    "routes": {
      "192.168.2.0/24": ["tag:subnet-router"],
      "10.0.0.0/24": ["tag:subnet-router"]
    }
  },
  "grants": [{ "src": ["*"], "dst": ["*"], "ip": ["*"] }],
  "ssh": [
    {
      "action": "check",
      "src": ["autogroup:member"],
      "dst": ["autogroup:self"],
      "users": ["autogroup:nonroot", "root"]
    }
  ]
}
```

## Troubleshooting

### Routes Not Working

```bash
# Check if routes are advertised
tailscale status --json | jq '.Peer[] | select(.HostName | startswith("node-")) | {name: .HostName, routes: .AllowedIPs}'

# Ensure --accept-routes is enabled on client
tailscale up --accept-routes
```

### Node Not Connecting

```bash
# Check tailscaled service
ssh raolivei@NODE_IP "sudo systemctl status tailscaled"

# Check logs
ssh raolivei@NODE_IP "sudo journalctl -u tailscaled -n 50"

# Re-authenticate if needed
ssh raolivei@NODE_IP "sudo tailscale up --auth-key=AUTHKEY --advertise-routes=192.168.2.0/24,10.0.0.0/24 --accept-routes=false --netfilter-mode=off"
```

### Pod Networking Broken After Tailscale Start

If k3s pod networking breaks after starting tailscaled:

```bash
# Check if table 52 has k8s routes (these should NOT exist)
ip route show table 52 | grep -E '10.42|10.43'

# Fix: remove k8s CIDRs from advertised routes and disable accept-routes/netfilter
sudo tailscale set --advertise-routes=192.168.2.0/24,10.0.0.0/24 --accept-routes=false --netfilter-mode=off
```

### Failover Not Working

Verify all 3 nodes are advertising the same routes:

```bash
tailscale status
# All node-* entries should show the same subnet ranges
```

## Security Notes

- Auth keys are stored in Vault at `secret/pi-fleet/tailscale`
- Keys are tagged with `tag:subnet-router` for ACL-based access control
- Tailscale uses WireGuard under the hood for encryption
- Traffic between your device and the cluster is end-to-end encrypted

## Enabling Tailscale

Tailscale is enabled when `tailscaled` is not in `disabled_services` in `ansible/group_vars/all.yml` (default is now empty). To use Tailscale as the way to reach all Eldertree services from your Mac:

1. Ensure `tailscaled` is not in `disabled_services` (if it is, remove it).
2. Run the Tailscale playbook (nodes will install/start Tailscale and advertise 192.168.2/24, 10.0.0/24):
   ```bash
   ROOT_TOKEN=$(kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.ROOT_TOKEN}' | base64 -d)
   AUTH_KEY=$(kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault kv get -field=auth-key secret/pi-fleet/tailscale")
   ansible-playbook -i inventory/hosts.yml playbooks/install-tailscale.yml -e "tailscale_auth_key=$AUTH_KEY"
   ```
3. In the [Tailscale admin console](https://login.tailscale.com/admin/acls), ensure **10.0.0.0/24** is in `autoApprovers.routes` if you use route approval.
4. On your Mac: Tailscale → Preferences → enable **Accept Routes**, then follow [Access all services from your Mac](#access-all-services-from-your-mac) (add the full `/etc/hosts` block and open `https://<service>.eldertree.local` for any service).

## VPN and eldertree.local access (design)

- **Tailscale (only VPN for Eldertree access):** No router port-forward. Nodes advertise 192.168.2/24 and 10.0.0/24 (NOT k8s CIDRs — see [Advertised Subnets](#advertised-subnets)). Mac uses Accept Routes plus either (a) DNS 192.168.2.201 + 1.1.1.1 so Pi-hole resolves `*.eldertree.local`, or (b) the full `/etc/hosts` block ([eldertree-local-hosts-block.txt](eldertree-local-hosts-block.txt)) when you cannot change DNS (e.g. corporate VPN). WireGuard is not used for Eldertree access.
- **eldertree.local:** **DNS path** — set Mac DNS to 192.168.2.201 and 1.1.1.1; Pi-hole resolves `*.eldertree.local` to 192.168.2.200. **Hosts-only path** — use the full `/etc/hosts` block with the Traefik EXTERNAL-IP (from `kubectl get svc traefik -n kube-system`); no DNS change required.

## Related Documentation

- [NETWORK.md](../NETWORK.md) - Network configuration overview
- [SERVICES_REFERENCE.md](../SERVICES_REFERENCE.md) - Service access guide
- [Ansible Playbook](../ansible/playbooks/install-tailscale.yml) - Installation automation
