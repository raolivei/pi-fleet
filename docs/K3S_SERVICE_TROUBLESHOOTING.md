# K3s Service Troubleshooting

## Issue: K3s Service Not Running

### Symptoms
- Cannot connect to cluster in Lens or kubectl
- `kubectl get nodes` returns connection timeout
- Service shows as "inactive (dead)" and "disabled"

### Root Cause
The K3s service was **disabled**, meaning it doesn't start automatically on boot. This can happen if:
1. System was rebooted and service wasn't enabled
2. Service was manually disabled
3. Service failed to start on boot and was disabled

### Solution

**Enable and start K3s service:**

```bash
ssh raolivei@node-0.local
sudo systemctl enable k3s
sudo systemctl start k3s
sudo systemctl status k3s
```

**Verify it's running:**
```bash
sudo systemctl is-enabled k3s  # Should show "enabled"
sudo systemctl is-active k3s   # Should show "active"
```

### Verify Connection

After starting the service, wait 10-30 seconds for it to fully initialize, then:

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
```

### Check Service Status

```bash
# Check if service is enabled
sudo systemctl is-enabled k3s

# Check if service is running
sudo systemctl status k3s

# Check service logs
sudo journalctl -u k3s -n 50

# Check if port is listening
sudo netstat -tlnp | grep 6443
# or
sudo ss -tlnp | grep 6443
```

### Common Issues

#### 1. Service Disabled
**Symptom:** Service shows as "disabled"
**Fix:**
```bash
sudo systemctl enable k3s
sudo systemctl start k3s
```

#### 2. Connection Timeout
**Symptom:** `kubectl get nodes` times out
**Possible causes:**
- Service not fully started (wait 10-30 seconds)
- Firewall blocking port 6443
- Wrong IP address in kubeconfig
- Network connectivity issues

**Check:**
```bash
# Verify service is running
sudo systemctl status k3s

# Check if port is listening
sudo ss -tlnp | grep 6443

# Test connectivity
curl -k https://localhost:6443/healthz

# Check kubeconfig server address
cat ~/.kube/config-eldertree | grep server
```

#### 3. Service Fails to Start
**Symptom:** `systemctl status k3s` shows failed state
**Check logs:**
```bash
sudo journalctl -u k3s -n 100
```

**Common causes:**
- K3s data directory missing or corrupted
- Port 6443 already in use
- Insufficient resources
- Disk space issues

#### 4. K3s Data Directory Issues
**Check:**
```bash
ls -la /var/lib/rancher/k3s/
df -h /var/lib/rancher/k3s
```

If using NVMe storage:
```bash
ls -la /mnt/nvme/k3s/
# Should be symlinked to /var/lib/rancher/k3s
```

### Prevention

**Ensure K3s starts on boot:**
```bash
sudo systemctl enable k3s
```

**Verify after reboot:**
```bash
sudo reboot
# After reboot
ssh raolivei@node-0.local
sudo systemctl status k3s
```

### Related Documentation

- [K3s Installation](../ansible/playbooks/install-k3s.yml) - K3s installation playbook
- [Cluster Setup](../README.md) - Complete cluster setup guide

