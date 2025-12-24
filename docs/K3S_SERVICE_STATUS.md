# K3s Service Status Investigation

## Issue: K3s Was Not Running

### Timeline
- **14:44:36 EST**: K3s service stopped (InactiveEnterTimestamp)
- **14:45:02 EST**: K3s service started (ActiveEnterTimestamp)
- **Current**: K3s is running and accessible

### Root Cause Analysis

1. **Service Status**: 
   - Service is **enabled** (should start on boot)
   - Service was **inactive (dead)** when checked initially
   - Service is now **active (running)**

2. **Possible Reasons It Stopped**:
   - Manual stop: `sudo systemctl stop k3s`
   - Service crash or error
   - System resource issue
   - Dependency issue (NetworkManager-wait-online.service not active)

3. **Current Status**:
   - ✅ K3s is running (PID 8571)
   - ✅ Port 6443 is listening (IPv6: `:::6443`)
   - ✅ Cluster is accessible via kubectl
   - ✅ Node is Ready: `node-0 Ready control-plane,etcd,master`

### Connection Issues

**Initial Problem**: Connection timeout to `https://192.168.2.86:6443`

**Resolution**: 
- K3s service was restarted
- Service is now running and accessible
- kubectl can connect successfully

**For Lens**:
- Kubeconfig location: `~/.kube/config-eldertree`
- Server: `https://192.168.2.86:6443`
- Cluster should now be accessible in Lens

### Service Configuration

**Service File**: `/etc/systemd/system/k3s.service`
- **Type**: notify
- **Wants**: network-online.target
- **After**: network-online.target
- **Enabled**: Yes (starts on boot)

### Dependencies

K3s depends on:
- `network-online.target` ✅
- `NetworkManager-wait-online.service` ⚠️ (not active, but not blocking)

### Verification Commands

```bash
# Check service status
ssh raolivei@node-0.eldertree.local "sudo systemctl status k3s"

# Check if running
ssh raolivei@node-0.eldertree.local "sudo systemctl is-active k3s"

# Check if enabled (starts on boot)
ssh raolivei@node-0.eldertree.local "sudo systemctl is-enabled k3s"

# Check port
ssh raolivei@node-0.eldertree.local "sudo ss -tlnp | grep 6443"

# Test connection
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
```

### Prevention

To ensure K3s starts on boot and stays running:

```bash
# Enable service (if not already)
ssh raolivei@node-0.eldertree.local "sudo systemctl enable k3s"

# Start service
ssh raolivei@node-0.eldertree.local "sudo systemctl start k3s"

# Verify
ssh raolivei@node-0.eldertree.local "sudo systemctl status k3s"
```

### Troubleshooting

If K3s stops again:

1. **Check logs**:
   ```bash
   ssh raolivei@node-0.eldertree.local "sudo journalctl -u k3s -n 100"
   ```

2. **Check for errors**:
   ```bash
   ssh raolivei@node-0.eldertree.local "sudo journalctl -u k3s --since '1 hour ago' | grep -i error"
   ```

3. **Restart service**:
   ```bash
   ssh raolivei@node-0.eldertree.local "sudo systemctl restart k3s"
   ```

4. **Check dependencies**:
   ```bash
   ssh raolivei@node-0.eldertree.local "sudo systemctl list-dependencies k3s.service"
   ```

### Current Cluster Status

```
NAME     STATUS   ROLES                       AGE    VERSION
node-0   Ready    control-plane,etcd,master   3d3h   v1.33.6+k3s1
```

Cluster is healthy and accessible.

