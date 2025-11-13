# Automatic DNS Setup for *.eldertree.local

Instead of manually editing `/etc/hosts`, configure AdGuard Home (adshield-pi) to automatically resolve `*.eldertree.local` domains.

## Setup via AdGuard Home Web UI

1. **Access AdGuard Home**:
   - URL: http://adshield.local (or http://192.168.2.83:30000)
   - Or via ingress if configured

2. **Add Custom DNS Records**:
   - Go to **Settings** → **DNS settings** → **DNS rewrites**
   - Click **Add DNS rewrite**
   - Add the following entries:
     ```
     Domain: canopy.eldertree.local
     IP: 192.168.2.83
     
     Domain: grafana.eldertree.local
     IP: 192.168.2.83
     
     Domain: prometheus.eldertree.local
     IP: 192.168.2.83
     
     Domain: vault.eldertree.local
     IP: 192.168.2.83
     ```

3. **Configure Wildcard (if supported)**:
   - Some AdGuard Home versions support wildcards
   - Try: `*.eldertree.local` → `192.168.2.83`
   - If not supported, add individual entries as above

## Setup via AdGuard Home API

If you prefer automation:

```bash
# Get AdGuard Home admin credentials (from initial setup)
ADGUARD_URL="http://adshield.local"
ADGUARD_USER="admin"
ADGUARD_PASS="your_password"

# Add DNS rewrites via API
curl -X POST "${ADGUARD_URL}/control/rewrite/add" \
  -u "${ADGUARD_USER}:${ADGUARD_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "canopy.eldertree.local",
    "answer": "192.168.2.83"
  }'

curl -X POST "${ADGUARD_URL}/control/rewrite/add" \
  -u "${ADGUARD_USER}:${ADGUARD_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "grafana.eldertree.local",
    "answer": "192.168.2.83"
  }'

curl -X POST "${ADGUARD_URL}/control/rewrite/add" \
  -u "${ADGUARD_USER}:${ADGUARD_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "prometheus.eldertree.local",
    "answer": "192.168.2.83"
  }'

curl -X POST "${ADGUARD_URL}/control/rewrite/add" \
  -u "${ADGUARD_USER}:${ADGUARD_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "vault.eldertree.local",
    "answer": "192.168.2.83"
  }'
```

## Configure macOS to Use AdGuard Home

1. **Get AdGuard Home IP**:
   ```bash
   # If running in k3s, get the NodePort service IP
   export KUBECONFIG=~/.kube/config-eldertree
   kubectl get svc -n adshield
   ```

2. **Set DNS on macOS**:
   - System Settings → Network → Your connection → Details → DNS
   - Add: `192.168.2.83` (or AdGuard Home service IP)
   - Or set as primary DNS in your router (recommended for network-wide)

## Verify Setup

```bash
# Test DNS resolution
nslookup canopy.eldertree.local
# Should return 192.168.2.83

# Test access
curl -k https://canopy.eldertree.local
```

## Benefits

- ✅ **Automatic** - No need to edit `/etc/hosts` manually
- ✅ **Network-wide** - Works for all devices if router DNS is configured
- ✅ **Persistent** - Survives reboots
- ✅ **Centralized** - Manage all DNS entries in one place

## Adding New Services

When deploying new services to eldertree:

1. Add DNS rewrite in AdGuard Home: `newservice.eldertree.local` → `192.168.2.83`
2. That's it! No `/etc/hosts` editing needed.
