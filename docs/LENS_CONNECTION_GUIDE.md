# Connecting Lens to Eldertree Cluster

This guide explains how to connect Lens (Kubernetes IDE) to the eldertree k3s cluster.

## Prerequisites

- ✅ Kubeconfig file created at `~/.kube/config-eldertree`
- ✅ Cluster accessible from your machine (network connectivity)
- ✅ Lens installed on your machine

## Quick Setup

The kubeconfig has been automatically configured. You can connect Lens using one of the following methods:

## Method 1: Import Kubeconfig File (Recommended)

1. **Open Lens**
2. **Click the "+" icon** in the top left (or go to **File → Add Cluster**)
3. **Select "From File"** or **"From Kubeconfig"**
4. **Navigate to:** `~/.kube/config-eldertree`
   - Full path: `/Users/roliveira/.kube/config-eldertree`
5. **Click "Add"** or **"Connect"**

Lens will automatically detect the cluster and context named "eldertree".

## Method 2: Auto-Detection (Alternative)

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

## Method 3: Manual Cluster Addition

If the above methods don't work, you can add the cluster manually:

1. **Open Lens**
2. **Click "+" → "Add Cluster"**
3. **Select "Custom"** or **"Enter manually"**
4. **Enter cluster details:**
   - **Name:** `eldertree`
   - **API Server:** `https://192.168.2.101:6443`
   - **Certificate Authority:** (from kubeconfig)
   - **Client Certificate:** (from kubeconfig)
   - **Client Key:** (from kubeconfig)

## Verification

After connecting, verify the connection:

1. **Check cluster status** - Should show "Connected" or green indicator
2. **View nodes** - You should see:
   - `node-1.eldertree.local` (control-plane)
   - `node-1.eldertree.local` (control-plane)
   - `node-2.eldertree.local` (worker)
   - `node-3.eldertree.local` (worker)
3. **View namespaces** - Should show system namespaces (kube-system, etc.)

## Troubleshooting

### Connection Issues

If Lens can't connect:

1. **Check network connectivity:**
   ```bash
   ping 192.168.2.101
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
- **Control Plane:** node-1.eldertree.local (192.168.2.101)
- **API Server:** https://192.168.2.101:6443
- **Kubernetes Version:** v1.33.6+k3s1
- **Nodes:** 4 (2 control-plane, 2 workers)

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




