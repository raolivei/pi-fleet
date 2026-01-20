# Tailscale VPN - HA Subnet Routing

Tailscale provides secure, zero-config VPN access to the eldertree cluster from anywhere with automatic high-availability failover.

## Overview

All 3 cluster nodes are configured as Tailscale subnet routers, advertising the home LAN and Kubernetes networks. If any node goes down, traffic automatically routes through another node (~15 seconds failover).

## Node Configuration

| Node   | Tailscale IP     | LAN IP         | Status        |
|--------|------------------|----------------|---------------|
| node-1 | 100.86.241.124   | 192.168.2.101  | Subnet Router |
| node-2 | 100.116.185.57   | 192.168.2.102  | Subnet Router |
| node-3 | 100.104.30.105   | 192.168.2.103  | Subnet Router |

## Advertised Subnets

| Subnet          | Description              |
|-----------------|--------------------------|
| 192.168.2.0/24  | Home LAN                 |
| 10.42.0.0/16    | Kubernetes pod network   |
| 10.43.0.0/16    | Kubernetes service network |

## Client Setup

### macOS

1. Download Tailscale from https://tailscale.com/download/mac
2. Install and login with the same account used for the cluster
3. Click the Tailscale icon in menu bar → **Preferences**
4. Enable **"Accept Routes"** (critical for subnet access)
5. Verify connection: `tailscale status`

### iOS/iPadOS

1. Install Tailscale from App Store
2. Login with same account
3. Go to Settings → Tailscale → Enable **"Allow local network access"**
4. The subnets will be automatically accepted

### Linux

```bash
# Install
curl -fsSL https://tailscale.com/install.sh | sh

# Connect with subnet routing enabled
sudo tailscale up --accept-routes

# Verify
tailscale status
```

## Verify Connectivity

```bash
# Check Tailscale status
tailscale status

# Ping cluster nodes via Tailscale IPs (always works)
ping 100.86.241.124   # node-1
ping 100.116.185.57   # node-2
ping 100.104.30.105   # node-3

# Access Kubernetes API
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes

# SSH to nodes
ssh raolivei@192.168.2.101

# Access services
curl -k https://vault.eldertree.local
curl -k https://grafana.eldertree.local
```

## Remote Access (Outside Home Network)

When accessing the cluster from outside your home network (mobile LTE, coffee shop, etc.), use the Tailscale direct IPs instead of LAN IPs.

### kubeconfig for Remote Access

A separate kubeconfig is available for remote access:

| Location | kubeconfig | API Server |
|----------|-----------|------------|
| Home (LAN) | `~/.kube/config-eldertree` | 192.168.2.100:6443 |
| Remote | `~/.kube/config-eldertree-remote` | 100.86.241.124:6443 |

**Usage:**

```bash
# When at home
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes

# When remote (mobile, travel, etc.)
export KUBECONFIG=~/.kube/config-eldertree-remote
kubectl get nodes
```

### SSH from Remote

Use Tailscale IPs for SSH when remote:

```bash
# Via Tailscale IPs (works from anywhere)
ssh raolivei@100.86.241.124  # node-1
ssh raolivei@100.116.185.57  # node-2
ssh raolivei@100.104.30.105  # node-3
```

### Create Remote kubeconfig (if needed)

If `~/.kube/config-eldertree-remote` doesn't exist:

```bash
CLIENT_CERT=$(grep client-certificate-data ~/.kube/config-eldertree | awk '{print $2}')
CLIENT_KEY=$(grep client-key-data ~/.kube/config-eldertree | awk '{print $2}')

cat > ~/.kube/config-eldertree-remote << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://100.86.241.124:6443
  name: eldertree-remote
contexts:
- context:
    cluster: eldertree-remote
    user: eldertree-admin
  name: eldertree-remote
current-context: eldertree-remote
users:
- name: eldertree-admin
  user:
    client-certificate-data: ${CLIENT_CERT}
    client-key-data: ${CLIENT_KEY}
EOF
```

> **Note:** Uses `insecure-skip-tls-verify` because the cluster TLS cert doesn't include Tailscale IPs.

## Administration

### Check Node Status

```bash
# From any node
ssh raolivei@192.168.2.101 "tailscale status"

# View advertised routes
ssh raolivei@192.168.2.101 "tailscale status --json | jq '.Self.AllowedIPs'"
```

### Re-run Ansible Playbook

If you need to reconfigure or add new nodes:

```bash
cd /path/to/pi-fleet/ansible

# Get auth key from Vault
export KUBECONFIG=~/.kube/config-eldertree
AUTH_KEY=$(kubectl exec -n vault vault-0 -- vault kv get -field=auth-key secret/pi-fleet/tailscale)

# Run playbook
ansible-playbook -i inventory/hosts.yml playbooks/install-tailscale.yml \
  -e "tailscale_auth_key=$AUTH_KEY"
```

### Generate New Auth Key

If the auth key expires or you need a new one:

1. Go to https://login.tailscale.com/admin/settings/keys
2. Generate new key with:
   - ✅ Reusable
   - ✅ Pre-authorized
   - Tag: `tag:subnet-router`
3. Update Vault:
   ```bash
   kubectl exec -n vault vault-0 -- vault kv put secret/pi-fleet/tailscale \
     auth-key="tskey-auth-NEW_KEY_HERE"
   ```

## Tailscale ACL Configuration

The Tailscale ACL (Access Control List) is configured in the Tailscale admin console:

```json
{
  "tagOwners": {
    "tag:subnet-router": ["autogroup:admin"]
  },
  "autoApprovers": {
    "routes": {
      "192.168.2.0/24": ["tag:subnet-router"],
      "10.42.0.0/16": ["tag:subnet-router"],
      "10.43.0.0/16": ["tag:subnet-router"]
    }
  },
  "grants": [
    {"src": ["*"], "dst": ["*"], "ip": ["*"]}
  ],
  "ssh": [
    {
      "action": "check",
      "src": ["autogroup:member"],
      "dst": ["autogroup:self"],
      "users": ["autogroup:nonroot", "root"]
    }
  ]
}
```

## Troubleshooting

### Routes Not Working

```bash
# Check if routes are advertised
tailscale status --json | jq '.Peer[] | select(.HostName | startswith("node-")) | {name: .HostName, routes: .AllowedIPs}'

# Ensure --accept-routes is enabled on client
tailscale up --accept-routes
```

### Node Not Connecting

```bash
# Check tailscaled service
ssh raolivei@NODE_IP "sudo systemctl status tailscaled"

# Check logs
ssh raolivei@NODE_IP "sudo journalctl -u tailscaled -n 50"

# Re-authenticate if needed
ssh raolivei@NODE_IP "sudo tailscale up --auth-key=AUTHKEY --advertise-routes=192.168.2.0/24,10.42.0.0/16,10.43.0.0/16 --accept-routes"
```

### Failover Not Working

Verify all 3 nodes are advertising the same routes:

```bash
tailscale status
# All node-* entries should show the same subnet ranges
```

## Security Notes

- Auth keys are stored in Vault at `secret/pi-fleet/tailscale`
- Keys are tagged with `tag:subnet-router` for ACL-based access control
- Tailscale uses WireGuard under the hood for encryption
- Traffic between your device and the cluster is end-to-end encrypted

## Related Documentation

- [NETWORK.md](../NETWORK.md) - Network configuration overview
- [SERVICES_REFERENCE.md](../SERVICES_REFERENCE.md) - Service access guide
- [Ansible Playbook](../ansible/playbooks/install-tailscale.yml) - Installation automation
