# Pi-hole DNS Server

Kubernetes-native Pi-hole deployment for automatic DNS resolution of `*.eldertree.local` domains.

## Features

- ✅ **Kubernetes-native** - Managed via ConfigMaps and Deployments
- ✅ **Automatic DNS rewrites** - Custom DNS entries via ConfigMap
- ✅ **Persistent storage** - Configuration survives pod restarts
- ✅ **Network-wide DNS** - Can be used as router DNS server
- ✅ **Ad-blocking** - Optional ad-blocking capabilities

## Architecture

- **Namespace**: `pihole`
- **Deployment**: Single replica optimized for Raspberry Pi
- **Storage**: 2Gi PVC using `local-path` storage class
- **DNS Port**: NodePort 30053 (UDP/TCP)
- **Web UI**: NodePort 30080 (HTTP), Ingress at `pihole.eldertree.local`

## DNS Configuration

Custom DNS entries are configured via ConfigMap (`pihole-dnsmasq`):

```yaml
address=/canopy.eldertree.local/192.168.2.83
address=/grafana.eldertree.local/192.168.2.83
address=/prometheus.eldertree.local/192.168.2.83
address=/vault.eldertree.local/192.168.2.83
address=/eldertree.local/192.168.2.83  # Wildcard
```

## Deployment

Pi-hole is automatically deployed via FluxCD GitOps:

```bash
# Manual deployment (if needed)
kubectl apply -f clusters/eldertree/infrastructure/pihole/

# Check status
kubectl get pods -n pihole
kubectl get svc -n pihole
```

## Access

- **Web UI**: https://pihole.eldertree.local
- **Direct**: http://192.168.2.83:30080
- **Admin Password**: Set via `pihole-secrets` Kubernetes secret (optional)

## Adding DNS Entries

1. **Via ConfigMap** (Recommended - GitOps):
   ```bash
   # Edit ConfigMap
   kubectl edit configmap pihole-dnsmasq -n pihole
   
   # Or update file
   vim clusters/eldertree/infrastructure/pihole/configmap.yaml
   kubectl apply -f clusters/eldertree/infrastructure/pihole/configmap.yaml
   
   # Restart to reload
   kubectl rollout restart deployment/pihole -n pihole
   ```

2. **Via Web UI**:
   - Navigate to **Local DNS** → **DNS Records**
   - Add new entry
   - Note: Changes via UI are stored in PVC, not ConfigMap

## Configuration

### Environment Variables

- `TZ`: Timezone (default: UTC)
- `FTLCONF_dns_listeningMode`: DNS listening mode (default: `all`)
- `WEBPASSWORD`: Admin password (from secret, optional)

### Secrets

Create `pihole-secrets` secret for admin password:

```bash
kubectl create secret generic pihole-secrets \
  -n pihole \
  --from-literal=webpassword='your_password'
```

## Resource Limits

Optimized for Raspberry Pi:

- **Requests**: 256Mi memory, 100m CPU
- **Limits**: 512Mi memory, 500m CPU

## Troubleshooting

**DNS not resolving:**
```bash
# Check pod status
kubectl get pods -n pihole

# Check logs
kubectl logs -n pihole deployment/pihole

# Verify ConfigMap
kubectl get configmap pihole-dnsmasq -n pihole -o yaml

# Test DNS from pod
kubectl exec -it deployment/pihole -n pihole -- nslookup canopy.eldertree.local
```

**ConfigMap not loading:**
```bash
# Check volume mounts
kubectl describe deployment pihole -n pihole

# Verify ConfigMap file in pod
kubectl exec -it deployment/pihole -n pihole -- cat /etc/dnsmasq.d/05-custom-dns.conf
```

## Network Configuration

To use Pi-hole as your DNS server:

1. **Router DNS** (Recommended):
   - Set Pi-hole as primary DNS: `192.168.2.83:30053`
   - All devices will automatically use Pi-hole

2. **Device DNS**:
   - macOS: System Settings → Network → DNS → Add `192.168.2.83`
   - Linux: Edit `/etc/resolv.conf` or use NetworkManager

See [../../NETWORK.md](../../NETWORK.md) for detailed DNS setup instructions.

