# ✅ Cloudflare Origin Certificate Created Successfully

## Status

The Cloudflare Origin Certificate for `pitanga.cloud` has been created via Terraform!

**Certificate ID:** `629102645327340994442813818610690199110807285187`

**Hostnames:**
- `pitanga.cloud`
- `*.pitanga.cloud` (covers `northwaysignal.pitanga.cloud` and all subdomains)

**Validity:** 15 years (expires: 2041-01-06)

## What Was Done

1. ✅ Updated Cloudflare API token with required permissions
2. ✅ Set all required Terraform variables to prevent resource destruction
3. ✅ Created Origin Certificate via Terraform
4. ✅ Certificate and private key extracted to `/tmp/`

## Next Steps

### 1. Store Certificate in Vault (Once Vault is Fixed)

Vault is currently unavailable (pod stuck due to missing node). Once Vault is running:

```bash
export KUBECONFIG=~/.kube/config-eldertree
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Store certificate and private key
kubectl exec -n vault $VAULT_POD -- vault kv put secret/pitanga/cloudflare-origin-cert \
  certificate="$(cat /tmp/pitanga-cert.pem)" \
  private-key="$(cat /tmp/pitanga-key.pem)"
```

Or use the script:
```bash
cd ~/WORKSPACE/raolivei/pi-fleet/terraform
./scripts/store-pitanga-cert-from-terraform.sh
```

### 2. Verify ExternalSecret Syncs to Kubernetes

The ExternalSecret at `clusters/eldertree/pitanga/cloudflare-origin-cert-external.yaml` will automatically sync the certificate from Vault to Kubernetes once Vault is available.

Check the secret:
```bash
kubectl get secret pitanga-cloudflare-origin-tls -n pitanga
```

### 3. Verify Ingress Uses the Certificate

The ingress resources already reference the secret:
- `pitanga/clusters/eldertree/pitanga/website-ingress.yaml`
- `pitanga/clusters/eldertree/pitanga/northwaysignal-ingress.yaml`

Both use: `secretName: pitanga-cloudflare-origin-tls`

## Files Created

- `/tmp/pitanga-cert.pem` - Certificate (PEM format)
- `/tmp/pitanga-key.pem` - Private key (PEM format, 600 permissions)

## Terraform State

The certificate is now managed by Terraform:
- Resource: `cloudflare_origin_ca_certificate.pitanga_cloud[0]`
- Private key: `tls_private_key.pitanga_cloud[0]`
- CSR: `tls_cert_request.pitanga_cloud[0]`

## Important Notes

1. **Vault Issue**: Vault pod is currently stuck in Pending due to missing node (`node-3.eldertree.local`). See `VAULT_ISSUE_DIAGNOSIS.md` for details.

2. **Temporary Workaround**: Certificate files are saved in `/tmp/` for manual storage once Vault is fixed.

3. **Certificate Management**: The certificate is now managed by Terraform. Any changes should be made via Terraform, not manually in Cloudflare Dashboard.

4. **Token Update**: The Cloudflare API token has been updated with the required permissions. Make sure to update it in Vault once Vault is running:
   ```bash
   kubectl exec -n vault $VAULT_POD -- vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token="YOUR_CLOUDFLARE_API_TOKEN"
   ```

## Verification

Once Vault is running and the certificate is stored:

1. Check ExternalSecret status:
   ```bash
   kubectl get externalsecret pitanga-cloudflare-origin-cert -n pitanga
   ```

2. Check Kubernetes secret:
   ```bash
   kubectl get secret pitanga-cloudflare-origin-tls -n pitanga -o yaml
   ```

3. Test HTTPS:
   ```bash
   curl -vI https://pitanga.cloud
   curl -vI https://northwaysignal.pitanga.cloud
   ```


