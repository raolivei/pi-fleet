# Quick Setup: Run Certificate Setup

To run the automated setup, you need to provide your Cloudflare API token.

## Option 1: Using Environment Variable (Quickest)

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/terraform

# Set your API token (must have "SSL and Certificates:Edit" permission)
export CLOUDFLARE_API_TOKEN="your-api-token-here"

# Run automated setup
./scripts/setup-pitanga-cert-auto.sh
```

## Option 2: Store Token in Vault First

```bash
# Store token in Vault
export KUBECONFIG=~/.kube/config-eldertree
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token='your-api-token-here'

# Run setup (will read from Vault)
cd ~/WORKSPACE/raolivei/pi-fleet/terraform
./scripts/setup-pitanga-cert-auto.sh
```

## Option 3: Interactive Setup

```bash
cd ~/WORKSPACE/raolivei/pi-fleet/terraform
./scripts/setup-pitanga-cert.sh
```

This will prompt you for the API token interactively.

## What the Script Does

1. ✅ Gets/validates Cloudflare API token
2. ✅ Retrieves Zone ID for pitanga.cloud
3. ✅ Runs Terraform plan
4. ✅ Applies Terraform (creates certificate)
5. ✅ Stores certificate in Vault
6. ✅ ExternalSecret automatically syncs to Kubernetes

## API Token Requirements

Your Cloudflare API token must have:

- **Zone** → **Zone** → **Read**
- **Zone** → **DNS** → **Edit**
- **Zone** → **SSL and Certificates** → **Edit** ← **Required for Origin Certificates**

## After Setup

1. Verify ExternalSecret: `kubectl get externalsecret pitanga-cloudflare-origin-cert -n pitanga`
2. Check secret: `kubectl get secret pitanga-cloudflare-origin-tls -n pitanga`
3. Set Cloudflare SSL mode to "Full (strict)" in Cloudflare Dashboard
4. Test: `curl -v https://pitanga.cloud`
