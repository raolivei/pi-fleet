# Flux Git write access (deploy key)

Flux uses the secret `flux-system` (from Vault) to clone and, for ImageUpdateAutomation, **push** to the pi-fleet repo. If there are no deploy keys on the repo yet, add one so Flux can push image tag updates.

## 1. Generate an SSH key (no passphrase)

On your machine:

```bash
# Optional: use a dedicated key for Flux
KEY_PATH=~/.ssh/flux_pi-fleet_ed25519
ssh-keygen -t ed25519 -C "flux-pi-fleet" -f "$KEY_PATH" -N ""
```

## 2. Add the public key as a deploy key on GitHub

1. Open: **https://github.com/raolivei/pi-fleet/settings/keys**
2. Click **Add deploy key**
3. **Title:** e.g. `eldertree-flux`
4. **Key:** paste the contents of the **public** key:
   ```bash
   cat "${KEY_PATH}.pub"
   ```
5. **Allow write access:** check this (required for ImageUpdateAutomation push)
6. Click **Add key**

## 3. Store the private key in Vault

From your machine (with access to the cluster):

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Replace KEY_PATH if you used a different path
KEY_PATH=~/.ssh/flux_pi-fleet_ed25519

kubectl exec -n vault vault-0 -- vault kv put secret/pi-fleet/flux/git \
  sshKey="$(cat "$KEY_PATH")"
```

## 4. Refresh the Flux secret in the cluster

So the `flux-system` Kubernetes secret is updated from Vault:

```bash
kubectl annotate externalsecret flux-system -n flux-system \
  force-sync=$(date +%s) --overwrite
```

## 5. Verify

- **Deploy keys:** https://github.com/raolivei/pi-fleet/settings/keys — you should see the new key with “Write” access.
- **Flux:** After a few minutes, ImageUpdateAutomation (e.g. `canopy-updates`) should be able to push. Check with:
  ```bash
  flux get image update canopy -n canopy
  kubectl get imageupdateautomation -n canopy
  ```

## Security note

The private key is only in Vault and in the `flux-system` secret in the cluster; it is not committed to Git. Restrict access to Vault and the cluster accordingly.
