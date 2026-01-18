# Terraform Infrastructure Setup

**NOTE**: k3s installation is handled by Ansible (`ansible/playbooks/install-k3s.yml`), not Terraform.

Terraform manages infrastructure and configuration for the eldertree cluster:

- **Cloudflare**: DNS records (A, CNAME), Tunnels, Origin Certificates
- **Vault**: Policies, Auth Methods, Secrets Engines (declarative security configuration)
- **Note**: TLS certificates for services are managed by cert-manager via Helm charts

## Remote State

Terraform state is stored in **Terraform Cloud** for persistence and collaboration:

- **Organization**: `eldertree`
- **Workspace**: `pi-fleet-terraform`
- **URL**: https://app.terraform.io/app/eldertree/workspaces/pi-fleet-terraform

This ensures state is preserved across CI runs and local development.

## Cluster Name

The cluster is named **eldertree** (matching the control plane hostname).

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with credentials

terraform init
terraform plan
terraform apply
```

## Prerequisites

- k3s must be installed first (use Ansible: `ansible-playbook ansible/playbooks/install-k3s.yml`)
- Cloudflare account with domain `eldertree.xyz` added
- Cloudflare API token with appropriate permissions
- Vault deployed and unsealed (for Vault resources)

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

2. **Store Secrets in Vault**:

   ```bash
   # Get Vault pod
   VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

   # Store Cloudflare API token for Terraform use
   kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token=YOUR_API_TOKEN_HERE

   # Store Cloudflare API token for External-DNS use
   kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/external-dns/cloudflare-api-token api-token=YOUR_API_TOKEN_HERE

   # Store Pi SSH username (optional, defaults to "pi")
   kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/terraform/pi-user pi-user=YOUR_USERNAME_HERE
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
- `swimto.eldertree.xyz` A record with proxy enabled (orange cloud)

Additional DNS records for Kubernetes services will be managed automatically by External-DNS.

### Cloudflare Tunnel

Terraform manages the Cloudflare Tunnel for `swimto.eldertree.xyz`:

- **Tunnel**: Created automatically via `cloudflare_tunnel` resource
- **Configuration**: Ingress rules configured via `cloudflare_tunnel_config`
- **DNS**: CNAME record created automatically pointing to tunnel
- **No port forwarding**: Works behind NAT/firewall

**Prerequisites:**

- Cloudflare Account ID (required for tunnels)
- API token with tunnel permissions

**Setup Steps:**

1. **Get Cloudflare Account ID**:

   - Cloudflare Dashboard → Right sidebar → Account ID
   - Or via API: `curl -X GET "https://api.cloudflare.com/client/v4/accounts" -H "Authorization: Bearer YOUR_API_TOKEN"`

2. **Configure terraform.tfvars**:

   ```hcl
   cloudflare_account_id = "your-account-id-here"
   ```

3. **Apply Terraform**:

   ```bash
   terraform apply
   ```

4. **Get Tunnel Token** (required for Kubernetes deployment):

   ```bash
   ./scripts/setup-tunnel-token.sh eldertree
   ```

   Or manually:

   - Cloudflare Dashboard → Zero Trust → Networks → Tunnels → Configure
   - Copy the token
   - Store in Vault: `kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/cloudflare-tunnel/token token="YOUR_TOKEN"`

5. **Deploy Tunnel in Kubernetes**:
   ```bash
   kubectl apply -k ~/WORKSPACE/raolivei/pi-fleet/clusters/eldertree/cloudflare-tunnel
   ```

**Terraform Outputs:**

- `cloudflare_tunnel_id` - Tunnel ID
- `cloudflare_tunnel_name` - Tunnel name
- `cloudflare_tunnel_cname` - CNAME target for DNS records

### Cloudflare Origin Certificates

Terraform can create and manage Cloudflare Origin Certificates:

#### swimto.eldertree.xyz

Terraform can generate components for Cloudflare Origin Certificate for `swimto.eldertree.xyz`:

- **Certificate**: Valid for 15 years (5475 days)
- **Hostnames**: `swimto.eldertree.xyz` and `*.eldertree.xyz` (wildcard)
- **Type**: RSA (2048-bit)

**After applying Terraform, store the certificate in Kubernetes:**

```bash
cd terraform
./scripts/store-swimto-cert-from-terraform.sh swimto
```

Or manually:

```bash
# Get certificate and key from Terraform output
terraform output -raw swimto_origin_certificate > cert.pem
terraform output -raw swimto_origin_private_key > key.pem

# Create Kubernetes secret
kubectl create secret tls swimto-cloudflare-origin-tls \
  --cert=cert.pem \
  --key=key.pem \
  -n swimto

# Clean up temporary files
rm cert.pem key.pem
```

**Terraform outputs:**

- `swimto_origin_certificate` - The certificate (PEM format)
- `swimto_origin_private_key` - The private key (PEM format, sensitive)
- `swimto_certificate_id` - Cloudflare certificate ID

#### pitanga.cloud

Terraform manages the Cloudflare Origin Certificate for `pitanga.cloud`:

- **Certificate**: Valid for 15 years (5475 days)
- **Hostnames**: `pitanga.cloud` and `*.pitanga.cloud` (wildcard)
- **Type**: RSA (2048-bit)

**Prerequisites:**

- `pitanga_cloud_zone_id` variable set in Terraform
- Cloudflare API token with "SSL and Certificates:Edit" permission
- See [ORIGIN_CERT_API_PERMISSIONS.md](ORIGIN_CERT_API_PERMISSIONS.md)

**After applying Terraform, store the certificate in Vault:**

```bash
./scripts/store-pitanga-cert-from-terraform.sh
```

This stores the certificate in Vault at `secret/pitanga/cloudflare-origin-cert`, which is then synced to Kubernetes via External Secrets Operator.

**Terraform outputs:**

- `pitanga_cloud_origin_certificate` - The certificate (PEM format)
- `pitanga_cloud_origin_private_key` - The private key (PEM format, sensitive)
- `pitanga_cloud_certificate_id` - Certificate ID in Cloudflare

**Adding New Hostnames:**

To add new hostnames (e.g., `newservice.pitanga.cloud`), simply update the `hostnames` list in `cloudflare.tf`:

```hcl
hostnames = [
  "pitanga.cloud",
  "*.pitanga.cloud",
  "newservice.pitanga.cloud"  # Add new hostname here
]
```

Then run `terraform apply`. The certificate will be updated automatically.

**Next steps after storing certificate:**

1. Set Cloudflare SSL/TLS mode to "Full (strict)" in Cloudflare Dashboard
2. Verify ingress is using the secret: `kubectl describe ingress swimto-web-public -n swimto`
3. Test HTTPS: `curl -v https://swimto.eldertree.xyz`

### Public IP Configuration

The `public_ip` variable should point to your public IP address. Options:

- **Static Public IP**: If you have a static IP, use it directly
- **Dynamic DNS**: Use a dynamic DNS service to get a hostname that resolves to your current IP
- **Router Port Forwarding**: Configure router to forward ports to your Raspberry Pi

### Troubleshooting

- **Zone ID not found**: Ensure domain is added to Cloudflare and nameservers are changed at Porkbun
- **API token errors**: Verify token has correct permissions (Zone:Read, DNS:Edit)
- **DNS not resolving**: Wait for nameserver propagation (can take 24-48 hours)

---

## Vault Configuration (Issue #23)

Terraform manages Vault configuration declaratively, replacing the shell script at `scripts/operations/setup-vault-policies.sh`.

### What's Managed

- **KV Secrets Engine v2**: Enabled at `secret/` path
- **Project Policies**: Per-project access control (canopy, swimto, journey, nima, etc.)
- **Infrastructure Policy**: Access to `secret/pi-fleet/*` and legacy paths
- **ESO Read-Only Policy**: For External Secrets Operator
- **Kubernetes Auth Method**: Pod authentication via ServiceAccounts
- **Kubernetes Auth Roles**: Per-project roles bound to namespaces
- **Service Tokens**: For External Secrets Operator (stored in `external-secrets` namespace)

### Prerequisites

1. **Vault must be deployed and unsealed**:
   ```bash
   kubectl get pods -n vault
   kubectl exec -n vault vault-0 -- vault status
   ```

2. **Port-forward for local development**:
   ```bash
   kubectl port-forward vault-0 8200:8200 -n vault
   ```

3. **Get Vault token**:
   ```bash
   export TF_VAR_vault_token=$(kubectl get secret vault-token -n external-secrets -o jsonpath='{.data.token}' | base64 -d)
   ```

### Configuration

Set Vault variables via environment or terraform.tfvars:

```bash
# Environment variables (recommended for sensitive values)
export TF_VAR_vault_address="http://127.0.0.1:8200"
export TF_VAR_vault_token="hvs.xxxxx"
export TF_VAR_skip_vault_resources="false"
```

Or in terraform.tfvars:

```hcl
vault_address = "http://127.0.0.1:8200"
# vault_token = "" # Use TF_VAR_vault_token instead
skip_vault_resources = false
```

### Applying Vault Resources

```bash
# Apply only Vault resources
terraform apply -target=vault_policy.project_policy -target=vault_policy.infrastructure_policy

# Or apply all resources
terraform apply
```

### Importing Existing Resources

If Vault policies already exist from the shell script, import them:

```bash
# Import existing policies
terraform import 'vault_policy.project_policy["canopy"]' canopy-policy
terraform import 'vault_policy.project_policy["swimto"]' swimto-policy
terraform import vault_policy.infrastructure_policy[0] infrastructure-policy
terraform import vault_policy.eso_readonly_policy[0] eso-readonly-policy

# Import Kubernetes auth backend
terraform import vault_auth_backend.kubernetes[0] kubernetes
```

### CI/CD Behavior

In GitHub Actions, Vault resources are **skipped** (`skip_vault_resources=true`) because:

1. CI doesn't have direct access to Vault
2. Vault configuration requires authentication tokens
3. These resources are typically managed locally or via GitOps

To manage Vault via CI, you would need to:
1. Expose Vault via ingress
2. Store VAULT_TOKEN in GitHub Secrets
3. Set `skip_vault_resources=false` in the workflow

### Migration from Shell Script

The shell script at `scripts/operations/setup-vault-policies.sh` is now deprecated.
Terraform provides the same functionality with benefits:

| Feature | Shell Script | Terraform |
|---------|-------------|-----------|
| Declarative | ❌ | ✅ |
| State tracking | ❌ | ✅ |
| Drift detection | ❌ | ✅ |
| Rollback | ❌ | ✅ |
| Reproducible | ⚠️ | ✅ |
| Version control | ✅ | ✅ |

### Outputs

After applying, Terraform provides these outputs:

```bash
terraform output vault_policies        # List of created policies
terraform output vault_kubernetes_auth_roles  # List of K8s auth roles
terraform output vault_enabled         # Whether Vault is managed
terraform output -json vault_project_tokens  # Service tokens (sensitive)
```

### Disaster Recovery

State is stored in Terraform Cloud. To recover:

1. Ensure Terraform Cloud access (TF_API_TOKEN)
2. Run `terraform init` to connect to remote state
3. Verify state: `terraform state list | grep vault`
4. Re-apply if needed: `terraform apply`

If Vault is completely reset:

```bash
# Skip imports, just apply fresh
terraform apply -target=vault_mount.kv_v2
terraform apply  # Apply all Vault resources
```
