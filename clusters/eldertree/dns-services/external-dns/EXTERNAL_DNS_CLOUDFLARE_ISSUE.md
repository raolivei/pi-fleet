# External-DNS Cloudflare API Token Issue

## Problem

The `external-dns-cloudflare` pod is failing with:
```
failed to initialize cloudflare provider: invalid credentials: key & email must not be empty
```

## Root Cause

External-DNS v0.18.0 appears to have a bug where it checks for `CF_API_KEY` and `CF_API_EMAIL` environment variables first, and doesn't properly fall back to `EXTERNAL_DNS_CLOUDFLARE_API_TOKEN` even when the token is correctly configured.

## Current Status

- ✅ Cloudflare API token is valid and stored in Vault
- ✅ Secret `external-dns-cloudflare-secret` exists and is synced
- ✅ Environment variable `EXTERNAL_DNS_CLOUDFLARE_API_TOKEN` is configured correctly
- ❌ External-DNS v0.18.0 is not reading the API token

## Impact

**Low Impact** - External-DNS Cloudflare is currently suspended because:
- Terraform already manages the Cloudflare Tunnel DNS record (`swimto.eldertree.xyz`)
- DNS records can be managed manually via Terraform
- The Cloudflare Tunnel is working correctly without External-DNS

## Workarounds

### Option 1: Suspend External-DNS (Current)
The HelmRelease is configured with `suspend: false` but the pod crashes. You can manually suspend it:
```bash
kubectl patch helmrelease external-dns-cloudflare -n external-dns --type merge -p '{"spec":{"suspend":true}}'
```

### Option 2: Use API Key/Email (Not Recommended)
You could use the old API key/email method, but API tokens are more secure:
```yaml
env:
  - name: CF_API_KEY
    valueFrom:
      secretKeyRef:
        name: external-dns-cloudflare-secret
        key: api-key
  - name: CF_API_EMAIL
    valueFrom:
      secretKeyRef:
        name: external-dns-cloudflare-secret
        key: email
```

### Option 3: Wait for External-DNS Update
Check if a newer version of external-dns fixes this issue:
- Current: v0.18.0
- Check: https://github.com/kubernetes-sigs/external-dns/releases

### Option 4: Use Terraform for DNS Management
Since Terraform already manages Cloudflare resources, you can continue using it for DNS records instead of External-DNS.

## Verification

To verify the API token works:
```bash
export KUBECONFIG=~/.kube/config-eldertree
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
API_TOKEN=$(kubectl exec -n vault $VAULT_POD -- vault kv get -field=api-token secret/external-dns/cloudflare-api-token)

curl -X GET "https://api.cloudflare.com/client/v4/zones?name=eldertree.xyz" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json"
```

## References

- External-DNS Cloudflare Provider: https://kubernetes-sigs.github.io/external-dns/latest/docs/tutorials/cloudflare/
- External-DNS GitHub: https://github.com/kubernetes-sigs/external-dns

