# Cloudflare Tunnel Setup for eldertree Cluster

Cloudflare Tunnel provides secure, outbound-only connections from your cluster to Cloudflare, eliminating the need for port forwarding.

**Deployment Method**: Kubernetes Deployment via FluxCD GitOps (consistent with External-DNS pattern)

**Note**: Uses raw Deployment instead of Helm chart because:

- `cloudflare-tunnel` Helm chart expects credentials file format (JSON)
- We use TUNNEL_TOKEN mode which is simpler with ExternalSecret
- Still GitOps-managed via FluxCD, just not via Helm chart

## Architecture

- **Tunnel Creation**: Terraform (creates tunnel via Cloudflare API)
- **Tunnel Connector**: Helm chart (`cloudflare-tunnel`) deployed via FluxCD
- **Tunnel Configuration**: Helm chart values (GitOps-managed)
- **DNS Records**: External-DNS (automatic via ingress annotations)
- **Secrets**: Vault + External Secrets Operator

## Why Cloudflare Tunnel?

- ✅ **No port forwarding** - Works without exposing ports
- ✅ **No exposed ports** - Outbound-only connections
- ✅ **Automatic HTTPS** - Cloudflare handles SSL/TLS
- ✅ **DDoS protection** - Built into Cloudflare
- ✅ **Works with dynamic IPs** - No need to update DNS
- ✅ **GitOps-managed** - Configuration in Git via Helm chart

## Prerequisites

1. Cloudflare account with `eldertree.xyz` domain
2. Cloudflare Account ID (for tunnels)
3. Cloudflare API token with tunnel permissions
4. Terraform configured (see `pi-fleet/terraform/README.md`)
5. Vault deployed and unsealed
6. External Secrets Operator deployed

## Setup Steps

### 1. Create Tunnel via Terraform

Tunnel creation is managed via Terraform. See `pi-fleet/terraform/README.md` for details.

**Quick Setup:**

1. **Get Cloudflare Account ID**:

   - Cloudflare Dashboard → Right sidebar → Account ID
   - Or via API: `curl -X GET "https://api.cloudflare.com/client/v4/accounts" -H "Authorization: Bearer YOUR_API_TOKEN"`

2. **Store Cloudflare API token in Vault**:

   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n vault $VAULT_POD -- vault kv put secret/terraform/cloudflare-api-token api-token="YOUR_API_TOKEN"
   ```

3. **Apply Terraform**:

   ```bash
   cd ~/WORKSPACE/raolivei/pi-fleet/terraform
   ./run-terraform.sh apply
   ```

   This will create the Cloudflare Tunnel (but not configure it - that's done via Helm).

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

### 4. Deploy Tunnel Connector (FluxCD)

The tunnel connector is deployed automatically via FluxCD GitOps:

```bash
# FluxCD will automatically deploy when you commit the manifests
# Or manually trigger:
kubectl apply -k ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/dns-services/cloudflare-tunnel
```

**Configuration**: Tunnel ingress rules are configured in Terraform:

- Edit `terraform/cloudflare.tf` (cloudflare_zero_trust_tunnel_cloudflared_config resource)
- Update the ingress rules
- Run `terraform apply` to update tunnel configuration
- The Kubernetes deployment automatically picks up the new configuration

### 5. DNS Records (External-DNS)

DNS records are managed automatically by External-DNS via ingress annotations:

```yaml
annotations:
  external-dns.alpha.kubernetes.io/hostname: swimto.eldertree.xyz
```

See `clusters/eldertree/swimto/ingress.yaml` for examples.

## Verification

```bash
# Check tunnel pod is running
kubectl get pods -n cloudflare-tunnel

# Check tunnel logs
kubectl logs -n cloudflare-tunnel deployment/cloudflared -f

# Check HelmRelease status
flux get helmrelease cloudflared -n cloudflare-tunnel

# Test HTTPS access
curl -v https://swimto.eldertree.xyz
```

## Configuration Management

### Update Tunnel Configuration

Tunnel ingress rules are managed via Terraform:

1. Edit `terraform/cloudflare.tf`
2. Update `cloudflare_zero_trust_tunnel_cloudflared_config` resource
3. Add/modify ingress rules:
   ```hcl
   ingress_rule {
     hostname = "new-service.eldertree.xyz"
     service  = "http://service.namespace.svc.cluster.local:80"
   }
   ```
4. Run `terraform apply`
5. Tunnel configuration updates automatically (no pod restart needed)

### Add New Routes

1. Edit `terraform/cloudflare.tf`
2. Add ingress rule to `cloudflare_zero_trust_tunnel_cloudflared_config.config.ingress_rule`
3. Run `terraform apply`
4. Tunnel picks up new routes automatically

## Troubleshooting

### Tunnel Not Connecting

1. **Check credentials**:

   ```bash
   kubectl get secret cloudflared-credentials -n cloudflare-tunnel
   kubectl get externalsecret cloudflared-credentials -n cloudflare-tunnel
   ```

2. **Check logs**:

   ```bash
   kubectl logs -n cloudflare-tunnel deployment/cloudflared
   ```

3. **Verify tunnel token** is correct in Cloudflare Dashboard

4. **Check deployment status**:
   ```bash
   kubectl get deployment cloudflared -n cloudflare-tunnel
   kubectl describe deployment cloudflared -n cloudflare-tunnel
   ```

### DNS Not Resolving

1. **Check DNS record** is created by External-DNS:

   ```bash
   kubectl get dnsendpoints -A
   ```

2. **Verify proxy** is enabled (orange cloud) in Cloudflare Dashboard

3. **Wait for DNS propagation** (can take a few minutes)

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

3. **Check ingress** rules in Terraform match your services:
   ```bash
   cd terraform
   terraform output cloudflare_tunnel_id
   # Verify rules in cloudflare.tf match your service endpoints
   ```

## Migration from Terraform-Managed Configuration

If you previously managed tunnel configuration via Terraform:

1. **Remove Terraform tunnel config** (already done - see `terraform/cloudflare.tf`)
2. **Update HelmRelease values** with your ingress rules
3. **Commit and push** - FluxCD will deploy the new configuration
4. **Verify** tunnel is working with new configuration

## References

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Kubernetes Deployment Guide](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/deploy-cloudflared-replicas/)
- [Cloudflare Helm Charts](https://github.com/cloudflare/helm-charts)
- [Terraform Cloudflare Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
