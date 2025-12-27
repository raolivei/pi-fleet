# Flannel Interface Configuration - Critical Lessons

## Problem: Flannel Using Wrong Interface

When configuring k3s to use a specific network interface for flannel (e.g., gigabit eth0 instead of management wlan0), flannel may ignore the `--flannel-iface` flag and use the wrong interface.

### Symptoms

- Flannel VXLAN interface shows wrong local IP:
  ```bash
  ip -d link show flannel.1
  # Shows: local 192.168.2.85 dev wlan0  # WRONG - should be eth0
  ```

- Logs show flannel choosing wrong interface:
  ```
  "The interface wlan0 with ipv4 address 192.168.2.85 will be used by flannel"
  ```

- Node annotations show wrong public IP:
  ```bash
  kubectl get node node-1 -o jsonpath='{.metadata.annotations.flannel\.alpha\.coreos\.com/public-ip}'
  # Shows: 192.168.2.85  # WRONG - should be 10.0.0.2
  ```

- Node args may show malformed flags:
  ```bash
  kubectl get node node-1 -o jsonpath='{.metadata.annotations.k3s\.io/node-args}'
  # Shows: ["agent","--node-ip","10.0.0.2","\\","--flannel-iface","eth0"]  # Has literal backslash!
  ```

## Root Causes

### 1. Malformed Service File (Most Common)

**Problem**: The k3s-agent.service file has malformed backslashes in the ExecStart command, causing flags to not be properly passed to k3s.

**Example of broken service file**:
```ini
ExecStart=/usr/local/bin/k3s \
    agent \
    --node-ip=10.0.0.2 \\
    --flannel-iface=eth0 \\
```

**Issues**:
- Trailing backslashes (`\\`) on lines that shouldn't have them
- Literal backslashes being passed as arguments to k3s
- Systemd not parsing the command correctly

**Correct format** (matching node-0):
```ini
ExecStart=/usr/local/bin/k3s \
    agent \
	'--node-ip=10.0.0.2' \
	'--flannel-iface=eth0'
```

**Key differences**:
- Flags wrapped in single quotes
- Only continuation lines have backslashes
- Last line has NO backslash
- Proper indentation with tabs

### 2. Flannel Public IP Annotation

Flannel uses the `flannel.alpha.coreos.com/public-ip` annotation to determine which interface to use. If this annotation points to wlan0's IP, flannel will use wlan0 even if `--flannel-iface=eth0` is set.

**Check current annotation**:
```bash
kubectl get node node-1 -o jsonpath='{.metadata.annotations.flannel\.alpha\.coreos\.com/public-ip}'
```

**Update annotation**:
```bash
kubectl annotate node node-1.eldertree.local \
  flannel.alpha.coreos.com/public-ip=10.0.0.2 \
  --overwrite
```

### 3. Interface Detection Order

Flannel detects interfaces in a specific order. If the public-ip annotation is wrong or missing, flannel may choose the interface with the default route (often wlan0) instead of respecting the `--flannel-iface` flag.

## Solution: Complete Fix Process

### Step 1: Fix Service File Format

**Critical**: The service file must match node-0's exact format.

```bash
# On the node, create correct service file
sudo tee /etc/systemd/system/k3s-agent.service > /dev/null << 'EOF'
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
Wants=network-online.target
After=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
EnvironmentFile=-/etc/systemd/system/k3s-agent.service.env
KillMode=process
Delegate=yes
User=root
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/k3s \
    agent \
	'--node-ip=10.0.0.2' \
	'--flannel-iface=eth0'
EOF
```

**Key points**:
- Flags wrapped in single quotes: `'--node-ip=10.0.0.2'`
- Only continuation lines have backslashes
- Last flag line has NO trailing backslash
- Use tabs for indentation (matching node-0)

### Step 2: Verify Service File is Parsed Correctly

```bash
# Check how systemd parses the ExecStart command
sudo systemctl show k3s-agent -p ExecStart --value

# Should show:
# { path=/usr/local/bin/k3s ; argv[]=/usr/local/bin/k3s agent --node-ip=10.0.0.2 --flannel-iface=eth0 ; ... }
# NO literal backslashes in argv[]
```

**If you see backslashes in argv[]**, the service file is still malformed.

### Step 3: Update Flannel Public IP Annotation

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Update annotation to gigabit IP
kubectl annotate node node-1.eldertree.local \
  flannel.alpha.coreos.com/public-ip=10.0.0.2 \
  --overwrite
```

### Step 4: Restart k3s-agent and Verify

```bash
# Reload systemd
sudo systemctl daemon-reload

# Stop k3s-agent
sudo systemctl stop k3s-agent

# Clean up flannel interface and config
sudo ip link delete flannel.1 2>/dev/null || true
sudo rm -rf /var/lib/rancher/k3s/agent/etc/flannel 2>/dev/null || true

# Start k3s-agent
sudo systemctl start k3s-agent

# Wait for flannel to initialize (20-30 seconds)
sleep 30

# Verify flannel is using correct interface
ip -d link show flannel.1 | grep -E 'local|dev'
# Should show: local 10.0.0.2 dev eth0
```

### Step 5: Verify in Logs

```bash
sudo journalctl -u k3s-agent --since '2 minutes ago' | grep -i 'interface.*flannel\|will be used'
# Should show: "The interface eth0 with ipv4 address 10.0.0.2 will be used by flannel"
```

### Step 6: Verify Node Annotations

```bash
kubectl get node node-1.eldertree.local -o jsonpath='{.metadata.annotations.k3s\.io/node-args}'
# Should show: ["agent","--node-ip","10.0.0.2","--flannel-iface","eth0"]
# NO literal backslashes!

kubectl get node node-1.eldertree.local -o jsonpath='{.metadata.annotations.flannel\.alpha\.coreos\.com/public-ip}'
# Should show: 10.0.0.2
```

## Verification Checklist

After fixing, verify:

- [ ] Service file has correct format (flags in quotes, no trailing backslashes)
- [ ] `systemctl show k3s-agent -p ExecStart --value` shows flags without literal backslashes
- [ ] Flannel public-ip annotation is set to gigabit IP (10.0.0.2)
- [ ] `ip -d link show flannel.1` shows `local 10.0.0.2 dev eth0`
- [ ] Logs show: "The interface eth0 with ipv4 address 10.0.0.2 will be used by flannel"
- [ ] Node args annotation shows clean flags: `["agent","--node-ip","10.0.0.2","--flannel-iface","eth0"]`
- [ ] `kubectl get nodes -o wide` shows InternalIP as gigabit IP (10.0.0.2)
- [ ] Pod-to-pod communication works across nodes

## Common Mistakes to Avoid

1. **Don't use double backslashes** (`\\`) - these become literal backslashes in arguments
2. **Don't leave trailing backslashes** on the last ExecStart line
3. **Don't forget single quotes** around flags - they prevent shell interpretation
4. **Don't skip the annotation update** - flannel uses public-ip annotation for interface detection
5. **Don't forget to clean up** - delete flannel.1 interface and config before restart

## Why This Matters

- **Performance**: Gigabit network (eth0) provides much better performance than WiFi (wlan0)
- **Reliability**: Dedicated cluster network is more stable than management network
- **Separation**: Keeps cluster traffic separate from management traffic
- **Scalability**: Gigabit network can handle more pod-to-pod traffic

## Related Documentation

- [Network Configuration](DNS_TROUBLESHOOTING.md) - Network troubleshooting
- [NVME Storage Setup](NVME_STORAGE_SETUP.md) - Storage configuration

