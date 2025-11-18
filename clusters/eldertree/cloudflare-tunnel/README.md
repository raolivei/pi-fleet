# Cloudflare Tunnel Setup for eldertree Cluster

Cloudflare Tunnel provides secure, outbound-only connections from your cluster to Cloudflare, eliminating the need for port forwarding.

**All Cloudflare resources are managed via Terraform** - see `pi-fleet/terraform/README.md` for complete setup.

## Why Cloudflare Tunnel?

- ✅ **No port forwarding** - Works without exposing ports
- ✅ **No exposed ports** - Outbound-only connections
- ✅ **Automatic HTTPS** - Cloudflare handles SSL/TLS
- ✅ **DDoS protection** - Built into Cloudflare
- ✅ **Works with dynamic IPs** - No need to update DNS
- ✅ **Infrastructure as Code** - Managed entirely via Terraform

## Prerequisites

1. Cloudflare account with `eldertree.xyz` domain
2. Cloudflare Account ID (for tunnels)
3. Cloudflare API token with tunnel permissions
4. Terraform configured (see `pi-fleet/terraform/README.md`)

## Setup Steps

### 1. Configure Terraform

All Cloudflare resources are managed via Terraform. See `pi-fleet/terraform/README.md` for details.

**Quick Setup:**

1. **Get Cloudflare Account ID**:

   - Cloudflare Dashboard → Right sidebar → Account ID
   - Or via API: `curl -X GET "https://api.cloudflare.com/client/v4/accounts" -H "Authorization: Bearer YOUR_API_TOKEN"`

2. **Update terraform.tfvars**:

   ```hcl
   cloudflare_account_id = "your-account-id-here"
   ```

3. **Apply Terraform**:

   ```bash
   cd ~/WORKSPACE/raolivei/pi-fleet/terraform
   terraform apply
   ```

   This will:

   - Create the Cloudflare Tunnel
   - Configure ingress rules (routes to Traefik)
   - Create DNS CNAME record
   - Remove conflicting A records

### 2. Get Tunnel Token

After Terraform creates the tunnel, get the token:

**Automated (recommended):**

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/terraform
./scripts/setup-tunnel-token.sh eldertree
```

**Manual:**

1. Cloudflare Dashboard → Zero Trust → Networks → Tunnels
2. Click on `eldertree` tunnel
3. Click **Configure** next to connector
4. Copy the **Tunnel Token** (starts with `eyJ...`)

### 3. Store Token in Vault

```bash
# Get Vault pod
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Store tunnel token
kubectl exec -n vault $VAULT_POD -- vault kv put secret/cloudflare-tunnel/token token="YOUR_TUNNEL_TOKEN_HERE"
```

### 4. Deploy Tunnel in Kubernetes

Apply the Kubernetes manifests:

```bash
kubectl apply -k ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/cloudflare-tunnel
```

**Note**: Tunnel routes are configured via Terraform (`cloudflare_tunnel_config` resource). No manual configuration needed in Cloudflare Dashboard.

## Verification

```bash
# Check tunnel pod is running
kubectl get pods -n cloudflare-tunnel

# Check tunnel logs
kubectl logs -n cloudflare-tunnel deployment/cloudflared -f

# Test HTTPS access
curl -v https://swimto.eldertree.xyz
```

## Troubleshooting

### Tunnel Not Connecting

1. **Check credentials**:

   ```bash
   kubectl get secret cloudflared-credentials -n cloudflare-tunnel
   ```

2. **Check logs**:

   ```bash
   kubectl logs -n cloudflare-tunnel deployment/cloudflared
   ```

3. **Verify tunnel token** is correct in Cloudflare Dashboard

### DNS Not Resolving

1. **Check DNS record** is CNAME pointing to tunnel (managed by Terraform)
2. **Verify proxy** is enabled (orange cloud)
3. **Wait for DNS propagation** (can take a few minutes)
4. **Check Terraform state**: `terraform output cloudflare_tunnel_cname`

### 502 Bad Gateway

1. **Check service** is accessible from tunnel pod:

   ```bash
   kubectl exec -n cloudflare-tunnel deployment/cloudflared -- \
     curl http://traefik.kube-system.svc.cluster.local:80
   ```

2. **Verify Traefik** is running:

   ```bash
   kubectl get svc -n kube-system traefik
   kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
   ```

3. **Check ingress** rules:
   ```bash
   kubectl get ingress -n swimto
   ```

## Terraform Management

All Cloudflare resources are managed via Terraform:

- **Tunnel**: `cloudflare_tunnel.eldertree`
- **Configuration**: `cloudflare_tunnel_config.eldertree`
- **DNS**: `cloudflare_record.swimto_eldertree_xyz_tunnel`

To update tunnel configuration, edit `pi-fleet/terraform/cloudflare.tf` and run `terraform apply`.

## References

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Kubernetes Deployment Guide](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/deploy-cloudflared-replicas/)
- [Terraform Cloudflare Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
