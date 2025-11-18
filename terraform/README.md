# Terraform K3s Setup

Automates k3s control plane installation on Raspberry Pi.

## Cluster Name

The cluster is named **eldertree** (matching the control plane hostname). Kubeconfig contexts are automatically configured with this name.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars

terraform init
terraform plan
terraform apply
```

## Post-Install

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl config use-context eldertree
kubectl get nodes
```

## Update Existing Kubeconfig

If you have an existing kubeconfig with default names:

```bash
./update-kubeconfig.sh ~/.kube/config-eldertree
```

## Cleanup

```bash
terraform destroy
```

## Cloudflare DNS Configuration

Terraform can manage DNS records for `eldertree.xyz` domain using Cloudflare DNS.

### Prerequisites

1. **Domain Registration**: Domain `eldertree.xyz` must be registered (currently registered at Porkbun)
2. **Cloudflare Account**: Create a Cloudflare account at https://dash.cloudflare.com/sign-up
3. **Add Domain to Cloudflare**:
   - Log in to Cloudflare dashboard
   - Click "Add Site" and enter `eldertree.xyz`
   - Cloudflare will scan existing DNS records
   - Select a plan (Free plan is sufficient)
4. **Change Nameservers at Porkbun**:
   - Cloudflare will provide two nameservers (e.g., `curitiba.ns.porkbun.com` → Cloudflare nameservers)
   - Log in to Porkbun account
   - Navigate to `eldertree.xyz` domain management
   - Go to DNS settings / Nameservers
   - Replace Porkbun nameservers with Cloudflare nameservers provided in Cloudflare dashboard
   - Wait for DNS propagation (can take up to 24-48 hours, usually faster)

### Cloudflare API Token Setup

1. **Create API Token**:
   - In Cloudflare dashboard, go to "My Profile" → "API Tokens"
   - Click "Create Token"
   - Use "Edit zone DNS" template or create custom token with:
     - Permissions: `Zone` → `DNS` → `Edit`
     - Permissions: `Zone` → `Zone` → `Read`
     - Zone Resources: Include `eldertree.xyz`
   - Create token and copy it (you won't be able to see it again)

2. **Store API Token in Vault**:
   ```bash
   # Get Vault pod
   VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
   
   # Store token for Terraform use
   kubectl exec -n vault $VAULT_POD -- vault kv put secret/terraform/cloudflare-api-token api-token=YOUR_API_TOKEN_HERE
   
   # Store token for External-DNS use
   kubectl exec -n vault $VAULT_POD -- vault kv put secret/external-dns/cloudflare-api-token api-token=YOUR_API_TOKEN_HERE
   ```

### Terraform Configuration

1. **Get Cloudflare Zone ID**:
   - After adding domain to Cloudflare, Zone ID is shown in dashboard
   - Navigate to `eldertree.xyz` → Overview → Zone ID (right sidebar)
   - Or use Cloudflare API: `curl -X GET "https://api.cloudflare.com/client/v4/zones?name=eldertree.xyz" -H "Authorization: Bearer YOUR_API_TOKEN"`

2. **Configure terraform.tfvars**:
   ```hcl
   # Cloudflare DNS Configuration
   cloudflare_api_token = "your-api-token-here"  # Or read from Vault
   cloudflare_zone_id   = "your-zone-id-here"
   public_ip            = "your-public-ip-address"
   ```

3. **Apply Terraform**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

### DNS Records

Terraform will create:
- Root domain A record: `eldertree.xyz` → `public_ip`
- Wildcard A record: `*.eldertree.xyz` → `public_ip`

Additional DNS records for Kubernetes services will be managed automatically by External-DNS.

### Public IP Configuration

The `public_ip` variable should point to your public IP address. Options:
- **Static Public IP**: If you have a static IP, use it directly
- **Dynamic DNS**: Use a dynamic DNS service to get a hostname that resolves to your current IP
- **Router Port Forwarding**: Configure router to forward ports to your Raspberry Pi

### Troubleshooting

- **Zone ID not found**: Ensure domain is added to Cloudflare and nameservers are changed at Porkbun
- **API token errors**: Verify token has correct permissions (Zone:Read, DNS:Edit)
- **DNS not resolving**: Wait for nameserver propagation (can take 24-48 hours)
