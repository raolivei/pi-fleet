# WireGuard Kubernetes Deployment Guide

This guide covers deploying WireGuard as a Kubernetes workload in the **eldertree** cluster using Helm.

## 📦 Deployment Options

You have two options for deploying WireGuard:

1. **Standalone scripts** (original): Direct installation on the Raspberry Pi host
2. **Helm chart** (recommended): Kubernetes-managed deployment with Kustomization support

## 🎯 Why Deploy in Kubernetes?

- ✅ **Consistent management**: Manage VPN alongside other cluster workloads
- ✅ **Version control**: Track configuration changes in git
- ✅ **Easy enable/disable**: Toggle via Kustomization
- ✅ **High availability**: Automatic restart on failure
- ✅ **Persistent storage**: Keys and config survive pod restarts
- ✅ **Monitoring**: Integrate with cluster monitoring stack

## 🚀 Deployment Steps

### 1. Verify Prerequisites

```bash
# Check kernel modules are loaded
ssh pi@<pi-ip> "lsmod | grep wireguard"

# If not loaded, load them
ssh pi@<pi-ip> "sudo modprobe wireguard"

# Make persistent
ssh pi@<pi-ip> "echo 'wireguard' | sudo tee -a /etc/modules"
```

### 2. Configure Values

Edit `clusters/eldertree/infrastructure/wireguard-values.yaml`:

```bash
cd /path/to/pi-fleet
nano clusters/eldertree/infrastructure/wireguard-values.yaml
```

Key settings to adjust:

```yaml
wireguard:
  # Adjust if your LAN uses different subnet
  allowedNetworks:
    - "192.168.1.0/24"  # Change to your LAN subnet

service:
  # kube-vip LoadBalancer IP (from 192.168.2.200/28 range)
  loadBalancerIP: "192.168.2.202"

env:
  # Your public IP or domain
  SERVERURL: "your.domain.com"
  # Or leave empty for auto-detection
```

### 3. Enable in Kustomization

Edit `clusters/eldertree/infrastructure/kustomization.yaml`:

```bash
nano clusters/eldertree/infrastructure/kustomization.yaml
```

Uncomment the WireGuard helm chart:

```yaml
helmCharts:
  # WireGuard VPN for cluster access
  - name: wireguard
    namespace: wireguard
    releaseName: wireguard
    repo: ""  # Local chart
    valuesFile: wireguard-values.yaml
    version: 0.1.0
```

### 4. Deploy Using Helm Directly

```bash
# From pi-fleet root directory
cd /path/to/pi-fleet

# Install the chart
helm install wireguard ./helm/wireguard \
  --namespace wireguard \
  --create-namespace \
  --values clusters/eldertree/infrastructure/wireguard-values.yaml

# Check deployment
kubectl get pods -n wireguard
kubectl get svc -n wireguard
```

### 5. Get Server Public Key

```bash
# Wait for pod to be ready
kubectl wait --for=condition=ready pod -n wireguard -l app.kubernetes.io/name=wireguard --timeout=120s

# Get public key
kubectl exec -n wireguard deployment/wireguard -c wireguard -- cat /config/publickey
```

Save this key - you'll need it for client configs.

### 6. Add Clients

#### Option A: Via Values File (Recommended)

Edit `wireguard-values.yaml`:

```yaml
wireguard:
  peers:
    - name: iphone
      publicKey: "CLIENT_PUBLIC_KEY_HERE"
      allowedIPs: "10.8.0.2/32"
      persistentKeepalive: 25
```

Apply changes:

```bash
helm upgrade wireguard ./helm/wireguard \
  --namespace wireguard \
  --values clusters/eldertree/infrastructure/wireguard-values.yaml
```

#### Option B: Via Secret (For Sensitive Data)

```bash
# Create secret with peer configs
kubectl create secret generic wireguard-peers \
  --namespace wireguard \
  --from-literal=peers='[{"name":"iphone","publicKey":"...","allowedIPs":"10.8.0.2/32"}]'
```

### 7. Generate Client Configs

Use the standalone script to generate client configs:

```bash
cd clusters/eldertree/wireguard

# Generate client config
./generate-client.sh iphone 2

# This creates: clients/iphone.conf and clients/iphone.png (QR code)
```

Update the client config with the server public key from step 5.

### 8. Configure Router Port Forwarding

Forward UDP port 51820 to the kube-vip LoadBalancer IP:

- **External Port**: 51820
- **Internal Port**: 51820
- **Protocol**: UDP
- **Internal IP**: kube-vip LoadBalancer IP (192.168.2.202)

Get the LoadBalancer IP:

```bash
kubectl get svc -n wireguard wireguard -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## 🔍 Verification

### Check Deployment Status

```bash
# Pod status
kubectl get pods -n wireguard

# Service status
kubectl get svc -n wireguard

# Check WireGuard interface
kubectl exec -n wireguard deployment/wireguard -c wireguard -- wg show

# Check logs
kubectl logs -n wireguard deployment/wireguard -c wireguard
kubectl logs -n wireguard deployment/wireguard -c dnsmasq
```

### Test from Client

1. Import the client config to your device
2. Connect to WireGuard
3. Run verification:

```bash
# Test tunnel
ping 10.8.0.1

# Test cluster access
ping 10.43.0.1

# Test DNS
nslookup kubernetes.default.svc.cluster.local 10.8.0.1

# Verify split-tunnel (should NOT show wg0)
ip route | grep default
```

## 🎛️ Management

### Enable/Disable WireGuard

**To Disable**:

Edit `infrastructure/kustomization.yaml` and comment out the helm chart:

```yaml
helmCharts:
  # Disabled WireGuard
  # - name: wireguard
  #   namespace: wireguard
  #   ...
```

Or uninstall directly:

```bash
helm uninstall wireguard --namespace wireguard
```

**To Re-enable**:

Uncomment in kustomization.yaml or reinstall via helm.

### Update Configuration

```bash
# Edit values
nano clusters/eldertree/infrastructure/wireguard-values.yaml

# Apply changes
helm upgrade wireguard ./helm/wireguard \
  --namespace wireguard \
  --values clusters/eldertree/infrastructure/wireguard-values.yaml

# Check rollout
kubectl rollout status deployment/wireguard -n wireguard
```

### Add More Clients

1. Generate client keys (use the script)
2. Add to `wireguard-values.yaml`
3. Run `helm upgrade`
4. Distribute client config

### Remove Client

1. Remove from `wireguard-values.yaml`
2. Run `helm upgrade`
3. Revoke client access (delete their private key)

## 🔧 Troubleshooting

### Pod CrashLoopBackOff

```bash
# Check logs
kubectl logs -n wireguard deployment/wireguard -c wireguard

# Common causes:
# - Kernel modules not loaded
# - Insufficient permissions
# - Invalid configuration

# Check node kernel modules
kubectl get nodes -o wide
ssh pi@<node-ip> "lsmod | grep wireguard"
```

### No LoadBalancer IP Assigned

```bash
# Check kube-vip pods
kubectl get pods -n kube-system -l app=kube-vip

# Check kube-vip logs
kubectl logs -n kube-system -l app=kube-vip --tail=50

# Check service events
kubectl describe svc -n wireguard wireguard

# Manually assign IP (use IP from 192.168.2.200/28 range)
kubectl patch svc wireguard -n wireguard -p '{"spec":{"loadBalancerIP":"192.168.2.202"}}'
```

### DNS Not Working

```bash
# Check dnsmasq logs
kubectl logs -n wireguard deployment/wireguard -c dnsmasq

# Check CoreDNS
kubectl get svc -n kube-system kube-dns

# Test from pod
kubectl exec -n wireguard deployment/wireguard -c wireguard -- \
  nslookup kubernetes.default.svc.cluster.local 10.8.0.1
```

### Clients Can't Connect

```bash
# Check if service has external IP
kubectl get svc -n wireguard

# Check WireGuard is listening
kubectl exec -n wireguard deployment/wireguard -c wireguard -- netstat -uln | grep 51820

# Check firewall on router
# Verify UDP 51820 is forwarded

# Check for handshakes
kubectl exec -n wireguard deployment/wireguard -c wireguard -- wg show wg0 latest-handshakes
```

### Routing Issues

```bash
# Check iptables rules
kubectl exec -n wireguard deployment/wireguard -c wireguard -- iptables -t nat -L -n -v

# Check IP forwarding
kubectl exec -n wireguard deployment/wireguard -c wireguard -- sysctl net.ipv4.ip_forward

# Should output: net.ipv4.ip_forward = 1
```

## 📊 Monitoring

### Basic Monitoring

```bash
# Watch pod status
kubectl get pods -n wireguard -w

# Monitor logs
kubectl logs -n wireguard deployment/wireguard -c wireguard -f

# Check connected peers
kubectl exec -n wireguard deployment/wireguard -c wireguard -- wg show wg0
```

### Prometheus Integration

If you have prometheus-operator installed:

```yaml
# In wireguard-values.yaml
monitoring:
  enabled: true
  interval: 30s
```

This creates a ServiceMonitor for Prometheus to scrape WireGuard metrics.

## 🔄 Migration from Standalone

If you were running WireGuard directly on the host:

1. **Backup existing config**:

```bash
ssh pi@<pi-ip> "sudo cp /etc/wireguard/wg0.conf ~/wg0.conf.backup"
ssh pi@<pi-ip> "sudo cp /etc/wireguard/privatekey ~/privatekey.backup"
```

2. **Stop host WireGuard**:

```bash
ssh pi@<pi-ip> "sudo systemctl stop wg-quick@wg0"
ssh pi@<pi-ip> "sudo systemctl disable wg-quick@wg0"
```

3. **Extract keys and peers** from backup config

4. **Deploy Kubernetes version** with same keys/peers

5. **Test thoroughly** before deleting host config

## 🔒 Security Best Practices

1. **Store keys in secrets**, not values files
2. **Use RBAC** to restrict access to wireguard namespace
3. **Enable network policies** to isolate WireGuard pod
4. **Rotate keys** every 6-12 months
5. **Monitor access logs** for suspicious activity
6. **Use strong pre-shared keys** (optional PSK support)

## 📚 Additional Resources

- [Helm Chart README](../../../helm/wireguard/README.md)
- [Original Setup Scripts](./README.md)
- [WireGuard Documentation](https://www.wireguard.com/)
- [k3s Networking](https://docs.k3s.io/networking)

## 🆘 Getting Help

1. Check pod logs
2. Review service configuration
3. Verify network connectivity
4. Check router port forwarding
5. Consult WireGuard documentation
6. Open issue in pi-fleet repository

---

**Note**: The Kubernetes deployment uses `hostNetwork: true` to avoid double-NAT issues. This means the WireGuard pod shares the host's network namespace, similar to running it directly on the host.

