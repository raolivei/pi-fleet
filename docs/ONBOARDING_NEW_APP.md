# Onboarding a New App to Eldertree

End-to-end checklist for deploying a new app (or a dev environment for an existing app) to the Eldertree K3s cluster. Follow the steps in order — each section gates the next.

**Related docs:**
- Routing details → [ONBOARDING_APP_ROUTING.md](ONBOARDING_APP_ROUTING.md)
- Observability → [ONBOARDING_APP_OBSERVABILITY.md](ONBOARDING_APP_OBSERVABILITY.md)
- Vault secrets reference → [VAULT_SECRETS_MANAGEMENT.md](VAULT_SECRETS_MANAGEMENT.md)

---

## 0. Pre-flight cluster health checks

Run these before touching any manifests. Broken shared services silently stall every subsequent step.

```bash
export KUBECONFIG=~/.kube/config-eldertree

# cert-manager webhook (blocks ALL cert issuance when 502ing)
kubectl get pod -n flux-system | grep cert-manager-issuers-webhook
# Expect: 1/1 Running, low restart count
# If restarts > 50 or CrashLoopBackOff: kubectl delete pod <pod> -n flux-system

# BIND9 + external-dns (blocks DNS registration)
kubectl get pod -n bind
kubectl get pod -n external-dns | grep -v cloudflare
# Expect both 1/1 Running
# If external-dns in CrashLoopBackOff: BIND9 journal desync — delete bind9 pod to reset

# Vault unsealed
kubectl exec -n vault vault-0 -- vault status | grep Sealed
# Expect: Sealed false
# If sealed: ./scripts/operations/unseal-vault.sh

# Flux healthy
flux get kustomization flux-system -n flux-system
# Expect: Applied revision: main@sha1:...
```

**Do not proceed if any of these are broken.** Fixing them takes minutes; debugging with a broken foundation takes hours.

---

## 1. Namespace + Kustomization

Create `clusters/eldertree/<app>/` and register it in the parent kustomization.

```yaml
# clusters/eldertree/<app>/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: <app>
```

```yaml
# clusters/eldertree/kustomization.yaml  (add one line)
resources:
  - <app>  # <app> description (ingress host, tag strategy)
```

---

## 2. Vault secrets (before pods start)

Pods will be stuck in `CreateContainerConfigError` if the secret doesn't exist at deploy time. **Provision Vault before pushing any HelmRelease.**

```bash
# 1. Add the policy file
cat > scripts/operations/policies/<app>-policy.hcl <<'HCL'
path "secret/data/<app>/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/metadata/<app>/*" {
  capabilities = ["list", "read", "delete"]
}
HCL

# 2. Register in setup-vault-policies.sh (3 lines — policy, token, secrets write)
#    See the swimto-dev block in that file as a template.

# 3. Run the script (idempotent)
export KUBECONFIG=~/.kube/config-eldertree
./scripts/operations/setup-vault-policies.sh
```

Then add the ExternalSecret manifest:

```yaml
# clusters/eldertree/<app>/<app>-secrets-external.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: <app>-secrets
  namespace: <app>
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault
    kind: ClusterSecretStore
  target:
    name: <app>-secrets
    creationPolicy: Owner
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: secret/<app>/app
        property: DATABASE_URL
    # add other keys as needed
```

Verify after Flux reconciles:

```bash
kubectl get externalsecret <app>-secrets -n <app>
# Status: SecretSynced

# If stuck: force sync
kubectl annotate externalsecret <app>-secrets -n <app> \
  force-sync=$(date +%s) --overwrite
```

---

## 3. HelmRelease

Use the `eldertree-app` chart. **Always set `timeout: 15m`** — the default 5 min is too short for image pulls on Pi cluster hardware.

```yaml
# clusters/eldertree/<app>/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: <app>
  namespace: <app>
spec:
  interval: 30m
  timeout: 15m                  # REQUIRED — default 5m times out on Pi
  install:
    remediation:
      retries: 3
  upgrade:
    cleanupOnFail: true
    remediation:
      retries: 3
  chart:
    spec:
      chart: ./helm/eldertree-app
      version: "0.1.3"
      sourceRef:
        kind: GitRepository
        name: flux-system
        namespace: flux-system
      interval: 12h
  targetNamespace: <app>
  releaseName: <app>
  values:
    components:
      <app>-api:
        replicas: 1
        image:
          repository: ghcr.io/raolivei/<app>-api
          tag: latest  # {"$imagepolicy": "<app>:<app>-api-policy:tag"}
          pullPolicy: Always
        # ...
    ingress:
      <app>-web:
        host: <app>.eldertree.local
        service: <app>-web
        port: 3000
        tls:
          secretName: <app>-tls
          certManager: true
        annotations:
          external-dns.alpha.kubernetes.io/hostname: <app>.eldertree.local
```

If a HelmRelease gets stuck in `Stalled` / `RetriesExceeded`:

```bash
flux reconcile helmrelease <app> -n <app> --force --reset
```

---

## 4. Image automation (dev environments)

Dev environments track `build-<timestamp>-<sha>` tags for auto-deploy on every main push. Prod tracks semver.

```yaml
# clusters/eldertree/<app>/image-policies.yaml
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: <app>-api-dev
  namespace: <app>
spec:
  image: ghcr.io/raolivei/<app>-api
  interval: 5m
  secretRef:
    name: ghcr-auth
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: <app>-api-dev-policy
  namespace: <app>
spec:
  imageRepositoryRef:
    name: <app>-api-dev
  filterTags:
    pattern: '^build-(?P<ts>\d{14})-'
    extract: '$ts'
  policy:
    alphabetical:
      order: asc
```

**Important:** ImagePolicies will show `version list argument cannot be empty` until the first `build-*` tag exists. This is normal — the first push to `main` after the CI change will populate them. Do not troubleshoot further until after a CI build runs.

Prod image policies (semver) live in `clusters/eldertree/<prod-app>/image-policies.yaml` and are separate.

---

## 5. TLS certificate

cert-manager creates `<app>-tls` automatically from the Ingress annotation `cert-manager.io/cluster-issuer: ca-cluster-issuer`. This happens within ~30 seconds of the Ingress being created — **if the cert-manager-issuers-webhook is healthy** (see step 0).

Verify:

```bash
kubectl get certificate -n <app>
# Expect: READY True

kubectl get secret <app>-tls -n <app>
# Expect: kubernetes.io/tls with 3 data keys
```

If no Certificate appears after 2 minutes:

```bash
# 1. Check webhook health
kubectl logs -n cert-manager cert-manager-<pod> --since=5m | grep -i "error\|502"

# 2. If 502s: restart the webhook
kubectl delete pod -n flux-system $(kubectl get pod -n flux-system -l app=cert-manager-issuers-webhook -o name | head -1 | cut -d/ -f2)

# 3. If webhook is healthy but cert still missing: create Certificate manually
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: <app>-tls
  namespace: <app>
spec:
  secretName: <app>-tls
  issuerRef:
    name: ca-cluster-issuer
    kind: ClusterIssuer
  dnsNames:
    - <app>.eldertree.local
EOF
```

---

## 6. DNS registration

External-dns reads the `external-dns.alpha.kubernetes.io/hostname` annotation on the Ingress and registers the hostname in BIND9 via RFC2136.

Verify BIND9 accepted the update:

```bash
# From BIND9 nodeport (within cluster network)
dig <app>.eldertree.local @192.168.2.101 -p 30053 +short
# Expect: 10.0.0.1 10.0.0.2 10.0.0.3 (Traefik VIP IPs)
```

If external-dns shows `SERVFAIL` errors in its logs → BIND9 journal desync. Fix:

```bash
kubectl delete pod -n bind $(kubectl get pod -n bind -l app=bind9 -o name | cut -d/ -f2)
# Wait ~15s for it to restart, then external-dns recovers automatically
```

On your Mac, flush DNS cache after registration:

```bash
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

---

## 7. Prod gate — controlling when swimto.app (or any prod app) updates

**Dev and prod must be explicitly decoupled.** By default the CI (`create-git-tag: true`) auto-bumps the semver PATCH version on every `main` push, which means every feature merge deploys to prod.

The correct setup:

| Environment | Image tag pattern | What triggers deploy |
|-------------|-------------------|----------------------|
| Dev (`<app>-dev`) | `build-<timestamp>-<sha>` | Every `main` push |
| Prod (`<app>`) | `semver >=X.Y.Z` | Only when a new semver tag is pushed |

To gate prod, set `create-git-tag: false` in the app's `build-and-push.yml`. To cut a prod release, either:
- Add a `VERSION` file bump to the commit (if CI reads it)
- Use `workflow_dispatch` with `create-git-tag: true`

See [swimTO PR #266](https://github.com/raolivei/swimTO/pull/266) for a reference implementation.

---

## 8. Smoke test

```bash
export KUBECONFIG=~/.kube/config-eldertree

# All pods running
kubectl get pods -n <app>

# HelmRelease healthy
kubectl get helmrelease <app> -n <app>
# Expect: Ready True

# TLS cert issued
kubectl get certificate -n <app>
# Expect: READY True

# DNS resolves
dig <app>.eldertree.local @192.168.2.101 -p 30053 +short

# Health endpoint (from inside cluster, bypasses Mac DNS)
kubectl run -it --rm smoke --image=curlimages/curl --restart=Never -n <app> -- \
  curl -sk https://<app>.eldertree.local/api/health --max-time 10
# Expect: {"status":"healthy",...}

# From Mac (after DNS flush)
curl -sk https://<app>.eldertree.local/api/health
```

---

## 9. Register the service

Once smoke test passes:

- [ ] Add to [`docs/eldertree-local-services.yaml`](eldertree-local-services.yaml)
- [ ] Add to [`docs/eldertree-local-hosts-block.txt`](eldertree-local-hosts-block.txt)
- [ ] Add to [`scripts/add-services-to-hosts.sh`](../scripts/add-services-to-hosts.sh)
- [ ] Add Caddy block to [`scripts/Caddyfile`](../scripts/Caddyfile)
- [ ] Add to [`docs/SERVICES_REFERENCE.md`](SERVICES_REFERENCE.md)
- [ ] Observability → [ONBOARDING_APP_OBSERVABILITY.md](ONBOARDING_APP_OBSERVABILITY.md)

---

## Common failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Pods `CreateContainerConfigError` | Vault secret not provisioned | Run `setup-vault-policies.sh`, force-sync ExternalSecret |
| HelmRelease `Stalled / RetriesExceeded` | 5m timeout hit; cert not ready | `flux reconcile helmrelease <app> -n <app> --force --reset` |
| No Certificate CR created | cert-manager-issuers-webhook 502 | Restart webhook pod (see step 5) |
| `swimto-dev-tls not found` | cert-manager webhook blocked cert creation | Create Certificate manually (see step 5) |
| `version list argument cannot be empty` | No `build-*` tags in ghcr yet | Normal — wait for first CI build on main |
| NXDOMAIN for `<app>.eldertree.local` | BIND9 journal desync or external-dns down | Delete bind9 pod (see step 6) |
| Mac can't resolve hostname after BIND9 fix | Stale Mac DNS cache | `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` |
| Prod app updated unexpectedly | CI has `create-git-tag: true` | Set `create-git-tag: false` in app's `build-and-push.yml` |
