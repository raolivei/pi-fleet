# Node-1 Recurring Issues - Root Cause Analysis

## Problem

Node-1 keeps experiencing failures:
- SSH connections closed immediately
- API server refusing connections
- Complete node unresponsiveness
- Requires frequent reboots

## Symptoms

```
❯ ssh node-1
Connection closed by 192.168.2.101 port 22
```

- SSH connection closes immediately (not timeout, but connection refused/closed)
- API server (6443) also refusing connections
- Node appears completely down from external network

## Possible Root Causes

### 1. Hardware Issues (Most Likely)

**Check:**
- **Power supply**: Insufficient or unstable power can cause crashes
- **SD Card/NVMe**: Failing storage can cause system hangs
- **Overheating**: Thermal throttling or shutdowns
- **Network cable**: Faulty cable or switch port

**Diagnosis:**
```bash
# If you have physical access:
# Check temperature
vcgencmd measure_temp

# Check power supply voltage
vcgencmd get_throttled

# Check disk health
sudo smartctl -a /dev/sda  # For NVMe
sudo dmesg | grep -i error
```

### 2. Resource Exhaustion

**Check:**
- **Memory (OOM)**: Out of memory kills processes
- **Disk space**: Full disk causes system failures
- **CPU**: 100% CPU can make system unresponsive

**Diagnosis:**
```bash
# Check memory usage
free -h
dmesg | grep -i "out of memory"

# Check disk space
df -h
du -sh /var/log/*

# Check for OOM kills
dmesg | grep -i "killed process"
journalctl -k | grep -i oom
```

### 3. k3s Service Crashes

**Check:**
- k3s service keeps crashing
- Systemd restarts failing
- Resource limits too low

**Diagnosis:**
```bash
# Check k3s service status
sudo systemctl status k3s
sudo journalctl -u k3s -n 100

# Check k3s logs
sudo journalctl -u k3s --since "1 hour ago" | grep -i error
```

### 4. Network Configuration Issues

**Check:**
- Network interface going down
- Routing table corruption
- Firewall blocking everything

**Diagnosis:**
```bash
# Check network interfaces
ip addr show
ip link show

# Check routing
ip route show

# Check firewall
sudo ufw status verbose
```

### 5. System Crashes / Kernel Panics

**Check:**
- Kernel panics
- System freezes
- Watchdog timeouts

**Diagnosis:**
```bash
# Check for kernel panics
dmesg | grep -i panic
journalctl -k | grep -i panic

# Check system logs
journalctl -p err -b
```

## Diagnostic Steps (When Node-1 is Accessible)

### Step 1: Check System Health

```bash
# SSH to node-1 (when accessible)
ssh roliveira@node-1.eldertree.local

# Check system resources
free -h
df -h
top -bn1 | head -20

# Check system load
uptime
```

### Step 2: Check k3s Service

```bash
# Check k3s status
sudo systemctl status k3s

# Check k3s logs for errors
sudo journalctl -u k3s -n 200 | grep -i error

# Check if k3s is consuming too many resources
ps aux | grep k3s
```

### Step 3: Check Network

```bash
# Check network interfaces
ip addr show
ip link show

# Check if interfaces are up
ip link show | grep -E "state UP|state DOWN"

# Test connectivity
ping -c 3 192.168.2.1
ping -c 3 8.8.8.8
```

### Step 4: Check Firewall

```bash
# Check UFW status
sudo ufw status verbose

# Check if SSH is allowed
sudo ufw status | grep -i ssh

# Check iptables
sudo iptables -L -n | head -20
```

### Step 5: Check System Logs

```bash
# Check for errors in last hour
sudo journalctl -p err --since "1 hour ago"

# Check for OOM kills
dmesg | grep -i "out of memory"
journalctl -k | grep -i oom

# Check for hardware errors
dmesg | grep -i error
```

## Immediate Recovery (When Node-1 is Down)

### Option 1: Physical Access (Recommended)

1. **Connect keyboard/monitor** to node-1
2. **Check if system is responsive** (can you see login prompt?)
3. **Login and check:**
   ```bash
   # Check system status
   systemctl status k3s
   systemctl status ssh
   
   # Check network
   ip addr show
   
   # Check resources
   free -h
   df -h
   ```

4. **Restart services:**
   ```bash
   sudo systemctl restart ssh
   sudo systemctl restart k3s
   ```

### Option 2: Power Cycle

If system is completely unresponsive:
1. **Power off** node-1 (unplug power)
2. **Wait 10 seconds**
3. **Power on** node-1
4. **Wait for boot** (2-3 minutes)
5. **Try SSH again**

### Option 3: Check from Other Nodes

From node-2 or node-3:
```bash
# Ping node-1
ping -c 3 192.168.2.101

# Try to access node-1's API
curl -k https://192.168.2.101:6443/healthz
```

## Prevention Strategies

### 1. Set Up Monitoring

Monitor node-1's health:
- CPU usage
- Memory usage
- Disk space
- k3s service status
- Network connectivity

**Tools:**
- Prometheus + Node Exporter
- Grafana dashboards
- Alertmanager for alerts

### 2. Resource Limits

Ensure k3s has proper resource limits:
```yaml
# In k3s service file or systemd override
[Service]
MemoryLimit=2G
CPUQuota=200%
```

### 3. Automatic Recovery

Set up systemd service to automatically restart k3s:
```ini
[Service]
Restart=always
RestartSec=10
StartLimitInterval=300
StartLimitBurst=5
```

### 4. Health Checks

Create a health check script that:
- Monitors k3s service
- Checks network connectivity
- Verifies API server is responding
- Automatically restarts if needed

### 5. Log Rotation

Prevent disk space issues:
```bash
# Configure log rotation
sudo logrotate -f /etc/logrotate.conf
```

## Comparison with Other Nodes

**Why node-2 and node-3 don't have these issues?**

Possible reasons:
1. **Different hardware** (node-1 might have failing component)
2. **Different workload** (node-1 might be running more pods)
3. **Different configuration** (node-1 might have misconfiguration)
4. **Age/wear** (node-1 might be older or more used)

**Action:** Compare node-1 configuration with node-2 and node-3:
```bash
# Compare k3s configuration
diff /etc/rancher/k3s/config.yaml node-1 node-2

# Compare system resources
# Check if node-1 has less RAM/CPU
```

## Recommended Actions

1. **Immediate:**
   - Power cycle node-1
   - Check hardware (power supply, temperature, storage)
   - Review system logs when accessible

2. **Short-term:**
   - Set up monitoring/alerting
   - Configure automatic restarts
   - Set resource limits

3. **Long-term:**
   - Consider replacing node-1 if hardware is failing
   - Set up load balancer (so node-1 failures don't affect access)
   - Document node-1's specific configuration differences

## Next Steps

1. When node-1 is accessible again, run full diagnostics
2. Compare node-1 with node-2/node-3
3. Set up monitoring to catch issues early
4. Document any hardware issues found


