# Connecting Lens to Eldertree Cluster

This guide explains how to connect Lens (Kubernetes IDE) to the eldertree k3s cluster.

## Prerequisites

- ✅ Kubeconfig file created at `~/.kube/config-eldertree` (LAN / VIP)
- ✅ Tailscale on the Mac when you are **not** on the Eldertree LAN (see [`TAILSCALE.md`](TAILSCALE.md): **Accept Routes**)
- ✅ Lens installed on your machine

## Recommended: one file, two contexts (fixes VIP timeouts)

The LAN kubeconfig points at **`https://192.168.2.100:6443`** (kube-vip). That times out in Lens when your Mac cannot reach `192.168.2.0/24` (off Wi‑Fi without working subnet routes).

Generate a **merged** kubeconfig (VIP + Tailscale node-1 API) and add **that** file to Lens:

```bash
bash ~/WORKSPACE/raolivei/pi-fleet/scripts/operations/merge-eldertree-kubeconfigs-for-lens.sh
```

Then in Lens: **Add cluster** → **From kubeconfig file** → `~/.kube/config-eldertree-lens`.

- **Context `eldertree-remote`** — API via node-1 Tailscale IP (default after the script). Use when you see `dial tcp 192.168.2.100:6443` timeouts.
- **Context `eldertree`** — API via VIP (HA). Use at home when subnet routing to `192.168.2.0/24` works.

Switch context in Lens (cluster settings / kubeconfig context) instead of maintaining two separate cluster entries.

## Quick Setup (LAN-only file)

Use this only when you are sure the VIP is reachable from your Mac.

1. **Open Lens**
2. **Click the "+" icon** in the top left (or go to **File → Add Cluster**)
3. **Select "From File"** or **"From Kubeconfig"**
4. **Navigate to:** `~/.kube/config-eldertree`
   - Full path: `/Users/roliveira/.kube/config-eldertree`
5. **Click "Add"** or **"Connect"**

Lens will detect the cluster and context named `eldertree`.

## Alternative: merge into default kubeconfig

Lens automatically detects clusters from `~/.kube/config`. To enable auto-detection:

1. **Merge the eldertree config into your default kubeconfig:**

   ```bash
   # Backup your current config (if it exists)
   cp ~/.kube/config ~/.kube/config.backup 2>/dev/null || true
   
   # Merge eldertree config
   KUBECONFIG=~/.kube/config:~/.kube/config-eldertree kubectl config view --flatten > ~/.kube/config.merged
   mv ~/.kube/config.merged ~/.kube/config
   chmod 600 ~/.kube/config
   ```

2. **Restart Lens** (if it's already running)

3. The eldertree cluster should appear automatically in Lens

## Manual cluster addition

If the above methods don't work, you can add the cluster manually:

1. **Open Lens**
2. **Click "+" → "Add Cluster"**
3. **Select "Custom"** or **"Enter manually"**
4. **Enter cluster details:**
   - **Name:** `eldertree`
   - **API Server:** `https://192.168.2.100:6443` (VIP for HA)
   - **Certificate Authority:** (from kubeconfig)
   - **Client Certificate:** (from kubeconfig)
   - **Client Key:** (from kubeconfig)

## Verification

After connecting, verify the connection:

1. **Check cluster status** - Should show "Connected" or green indicator
2. **View nodes** - You should see:
   - `node-1.eldertree.local` (control-plane, etcd, master)
   - `node-2.eldertree.local` (control-plane, etcd, master)
   - `node-3.eldertree.local` (control-plane, etcd, master)
3. **View namespaces** - Should show system namespaces (kube-system, etc.)

## Troubleshooting

### Connection Issues

#### `dial tcp 192.168.2.100:6443: connect: operation timed out`

The LAN kubeconfig points at the kube-vip address `192.168.2.100`. That only works when your Mac can reach the home LAN (same Wi‑Fi/VLAN) **or** Tailscale is up with **Accept Routes** so `192.168.2.0/24` is routed via the cluster.

**Fix (recommended for Lens):** use the merged kubeconfig (VIP + Tailscale in one file) or add the remote file only:

1. Tailscale: connected, **Accept Routes** enabled (`tailscale status`).
2. **Preferred:** merged file (switch context in Lens):

   ```bash
   bash ~/WORKSPACE/raolivei/pi-fleet/scripts/operations/merge-eldertree-kubeconfigs-for-lens.sh
   ```

   Lens → **Add Cluster** → `~/.kube/config-eldertree-lens` → context **`eldertree-remote`**.

3. **Or** regenerate remote only after cert rotation on the LAN config:

   ```bash
   bash ~/WORKSPACE/raolivei/pi-fleet/scripts/operations/sync-kubeconfig-eldertree-remote.sh
   ```

   Lens → **From kubeconfig file** → `~/.kube/config-eldertree-remote`.

Details: [`docs/TAILSCALE.md`](TAILSCALE.md) (remote kubeconfig + Lens).

#### `dial tcp 100.x.x.x:6443: i/o timeout` (Tailscale / `eldertree-remote`)

That address is a **node Tailscale IP**, not the VIP. A timeout usually means the **Tailscale data path to that node is unhealthy** (common on node-1 when `tailscale status` shows **`rx 0`** or a stuck **relay** while node-2 shows **direct**).

1. From a pi-fleet checkout:

   ```bash
   bash scripts/operations/diagnose-eldertree-tailscale-k8s-api.sh
   ```

2. Regenerate the remote kubeconfig using a node whose `:6443` check passed (often node-2):

   ```bash
   ELDERTREE_TS_API_IP=100.116.185.57 bash scripts/operations/sync-kubeconfig-eldertree-remote.sh
   bash scripts/operations/merge-eldertree-kubeconfigs-for-lens.sh
   ```

3. On the affected Pi (when you can SSH): `sudo systemctl restart tailscaled` and confirm `tailscale status` on the node.

---

If Lens can't connect:

1. **Check network connectivity:**
   ```bash
   ping 192.168.2.100  # VIP
   ping 192.168.2.101  # node-1
   ping 192.168.2.102  # node-2
   ping 192.168.2.103  # node-3
   ```

2. **Test with kubectl:**
   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   kubectl cluster-info
   kubectl get nodes
   ```

3. **Check firewall rules** - Ensure port 6443 is accessible

4. **Verify kubeconfig:**
   ```bash
   kubectl config view --kubeconfig=~/.kube/config-eldertree
   ```

### Certificate Issues

If you see certificate errors:

1. **Regenerate kubeconfig** from node-1:
   ```bash
   cd ~/WORKSPACE/raolivei/pi-fleet
   ./scripts/setup-kubeconfig-eldertree.sh
   ```

2. **Check certificate validity:**
   ```bash
   kubectl config view --kubeconfig=~/.kube/config-eldertree --raw | grep certificate-authority-data
   ```

### Lens Not Detecting Cluster

1. **Restart Lens** completely
2. **Check Lens settings** - Ensure kubeconfig path is correct
3. **Check file permissions:**
   ```bash
   ls -la ~/.kube/config-eldertree
   # Should be: -rw------- (600)
   ```

## Cluster Information

- **Cluster Name:** eldertree
- **VIP (HA):** 192.168.2.100
- **API Server:** https://192.168.2.100:6443
- **Kubernetes Version:** v1.33.6+k3s1 / v1.34.3+k3s1
- **Nodes:** 3 (all control-plane with etcd)
  - node-1: 192.168.2.101
  - node-2: 192.168.2.102
  - node-3: 192.168.2.103

## Useful Lens Features

Once connected, you can:

- **View Pods** - Browse all pods across namespaces
- **View Services** - See all services and their endpoints
- **View Ingress** - Check ingress configurations
- **Terminal Access** - Open terminal sessions in pods
- **Logs** - View pod logs in real-time
- **Resource Metrics** - Monitor CPU, memory, and network usage
- **YAML Editor** - Edit resources directly

## Reconnecting After Changes

If you need to reconnect after cluster changes:

```bash
# Re-run the setup script
cd ~/WORKSPACE/raolivei/pi-fleet
./scripts/setup-kubeconfig-eldertree.sh
```

Then refresh the cluster in Lens (right-click → "Refresh" or restart Lens).

## Additional Resources

- [Lens Documentation](https://k8slens.dev/)
- [K3s Documentation](https://k3s.io/)
- [Cluster Setup Guide](./pi-fleet-blog/chapters/05-cluster-setup.md)




