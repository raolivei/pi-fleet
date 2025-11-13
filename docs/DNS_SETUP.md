# Automatic DNS Setup for *.eldertree.local

Instead of manually editing `/etc/hosts`, configure Pi-hole to automatically resolve `*.eldertree.local` domains.

## Architecture

Pi-hole runs in Kubernetes and uses dnsmasq for DNS resolution. Custom DNS entries are configured via ConfigMap, which dnsmasq automatically loads from `/etc/dnsmasq.d/`.

## DNS Entries

The following domains are automatically configured via ConfigMap:

- `canopy.eldertree.local` → `192.168.2.83`
- `grafana.eldertree.local` → `192.168.2.83`
- `prometheus.eldertree.local` → `192.168.2.83`
- `vault.eldertree.local` → `192.168.2.83`
- `*.eldertree.local` → `192.168.2.83` (wildcard)

## Setup via Pi-hole Web UI

1. **Access Pi-hole**:
   - URL: https://pihole.eldertree.local
   - Or: http://192.168.2.83:30080
   - Default password: Set via `pihole-secrets` Kubernetes secret

2. **Verify DNS Entries**:
   - Go to **Local DNS Records** (or **Local DNS** → **DNS Records**)
   - You should see the custom entries configured via ConfigMap
   - These are managed via Kubernetes ConfigMap, so changes should be made there

3. **Add Additional Entries** (if needed):
   - Via Web UI: **Local DNS** → **DNS Records** → **Add**
   - Or update ConfigMap: `clusters/eldertree/infrastructure/pihole/configmap.yaml`

## Setup via Kubernetes ConfigMap

To add new DNS entries, update the ConfigMap:

```bash
# Edit the ConfigMap
kubectl edit configmap pihole-dnsmasq -n pihole

# Or update the file and apply
kubectl apply -f clusters/eldertree/infrastructure/pihole/configmap.yaml

# Restart Pi-hole to reload dnsmasq config
kubectl rollout restart deployment/pihole -n pihole
```

Example ConfigMap entry:
```yaml
data:
  05-custom-dns.conf: |
    address=/newservice.eldertree.local/192.168.2.83
```

## Setup via Pi-hole API

Pi-hole also supports API-based configuration:

```bash
# Get Pi-hole admin password from secret
export KUBECONFIG=~/.kube/config-eldertree
PIHOLE_PASS=$(kubectl get secret pihole-secrets -n pihole -o jsonpath='{.data.webpassword}' | base64 -d)
PIHOLE_URL="http://192.168.2.83:30080"

# Add DNS record via API
curl -X POST "${PIHOLE_URL}/admin/api.php" \
  -d "auth=${PIHOLE_PASS}" \
  -d "action=addCustomDNSAddress" \
  -d "domain=newservice.eldertree.local" \
  -d "ip=192.168.2.83"
```

## Configure macOS to Use Pi-hole

1. **Get Pi-hole DNS Port**:
   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   kubectl get svc pihole -n pihole
   # DNS is available on NodePort 30053 (UDP/TCP)
   ```

2. **Set DNS on macOS**:
   - System Settings → Network → Your connection → Details → DNS
   - Add: `192.168.2.83` (Pi-hole NodePort 30053)
   - Or set as primary DNS in your router (recommended for network-wide)

3. **Router Configuration (Recommended)**:
   - Set Pi-hole as primary DNS server: `192.168.2.83:30053`
   - All devices on the network will automatically use Pi-hole

## Verify Setup

```bash
# Test DNS resolution
nslookup canopy.eldertree.local 192.168.2.83
# Should return 192.168.2.83

# Test with dig
dig @192.168.2.83 canopy.eldertree.local
# Should return A record: 192.168.2.83

# Test access
curl -k https://canopy.eldertree.local
```

## Benefits

- ✅ **Kubernetes-native** - Managed via ConfigMaps and Deployments
- ✅ **Automatic** - No need to edit `/etc/hosts` manually
- ✅ **Network-wide** - Works for all devices if router DNS is configured
- ✅ **Persistent** - Survives reboots via PVC
- ✅ **Centralized** - Manage all DNS entries via Kubernetes manifests
- ✅ **GitOps-friendly** - Changes tracked in Git, deployed via FluxCD

## Adding New Services

When deploying new services to eldertree:

1. Update ConfigMap: `clusters/eldertree/infrastructure/pihole/configmap.yaml`
2. Add entry: `address=/newservice.eldertree.local/192.168.2.83`
3. Apply: `kubectl apply -f clusters/eldertree/infrastructure/pihole/configmap.yaml`
4. Restart: `kubectl rollout restart deployment/pihole -n pihole`
5. Commit and push - FluxCD will sync automatically

## Troubleshooting

**DNS not resolving:**
```bash
# Check Pi-hole pod status
kubectl get pods -n pihole

# Check dnsmasq config
kubectl exec -it deployment/pihole -n pihole -- cat /etc/dnsmasq.d/05-custom-dns.conf

# Check Pi-hole logs
kubectl logs -n pihole deployment/pihole
```

**ConfigMap not loading:**
- Ensure ConfigMap is mounted correctly in deployment
- Check volume mounts: `kubectl describe deployment pihole -n pihole`
- Restart deployment: `kubectl rollout restart deployment/pihole -n pihole`
