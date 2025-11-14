# AI Prompt: K3s Cluster Setup with GitOps

Use this prompt to replicate the eldertree cluster setup on similar infrastructure.

## Objective

Set up a production-ready single-node K3s cluster on a Raspberry Pi with:

- GitOps-based deployment using Flux
- Monitoring stack (Prometheus + Grafana)
- Certificate management with self-signed TLS
- Secrets management with Vault and External Secrets Operator
- Custom Helm charts for modular deployments
- All infrastructure as code

## Context

**Hardware:**

- Raspberry Pi 5 (8GB, ARM64)
- Debian 12 Bookworm
- Single-node cluster (workers can be added later)
- Hostname: eldertree
- IP: 192.168.2.83

**Repository Structure:**

```
pi-fleet/
├── terraform/          # K3s installation
├── clusters/eldertree/ # Cluster manifests
├── helm/              # Custom Helm charts
├── NETWORK.md         # Network configuration
├── VAULT.md           # Vault secrets management
├── STATUS.md          # Current state
└── CHANGELOG.md       # Changes tracking
```

## Requirements

1. **Use Helm charts where applicable** - Prefer Helm charts for all deployments when suitable charts exist. This provides better maintainability, reusability, and version management. When Helm charts are not available or not suitable, use raw YAML manifests.
2. **Keep it simple** - Concise documentation, no over-engineering
3. **GitOps workflow** - All changes via git commits
4. **Branching strategy** - Work in `infra/pi-fleet` branch, following conventions in CONTRIBUTING.md
5. **Commit frequently** - Commit at milestone achievements
6. **Update CHANGELOG** - Track all additions/changes/removals

## Implementation Steps

### 1. Network Documentation

- Create `NETWORK.md` with current IP, static IP setup guide, and service domains
- Document `/etc/hosts` entries for local DNS
- Keep it concise and actionable

### 2. Bootstrap Flux GitOps

```bash
# Install Flux CLI
brew install fluxcd/tap/flux

# Install Flux to cluster
flux install

# Create deploy key and add to GitHub
flux create secret git flux-system --url=ssh://git@github.com/USER/REPO --export
gh repo deploy-key add /path/to/key.pub --repo USER/REPO --title "flux-CLUSTER" --allow-write

# Configure GitRepository and Kustomization
# Point to: ./pi-fleet/clusters/eldertree
```

### 3. Deploy cert-manager (Helm Chart)

```yaml
# HelmRepository + HelmRelease in clusters/eldertree/infrastructure/cert-manager/
# Use official jetstack Helm chart
# Version: v1.16.2+
# Enable CRDs in values
```

### 4. Create Custom Helm Chart: cert-manager-issuers

```
helm/cert-manager-issuers/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── selfsigned-issuer.yaml
    └── acme-issuer.yaml (disabled by default)
```

Key: Separate issuers from cert-manager to avoid CRD race conditions.

### 5. Create Custom Helm Chart: monitoring-stack

```
helm/monitoring-stack/
├── Chart.yaml
├── Chart.lock
├── values.yaml
├── charts/
│   ├── prometheus-25.30.1.tgz
│   └── grafana-8.8.2.tgz
└── templates/
    └── namespace.yaml
```

**Important values to set:**

```yaml
global:
  domain: CLUSTER.local
  clusterIssuer: selfsigned-cluster-issuer
  storageClass: local-path # Use K3s built-in storage

prometheus:
  enabled: true
  server:
    persistentVolume:
      enabled: true
      size: 8Gi
      storageClass: local-path
    ingress:
      enabled: true
      ingressClassName: traefik
      hosts: [prometheus.CLUSTER.local]
      tls: [...]
      annotations:
        cert-manager.io/cluster-issuer: selfsigned-cluster-issuer

grafana:
  enabled: true
  adminPassword: admin
  persistence:
    enabled: true
    size: 2Gi
    storageClassName: local-path
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://monitoring-stack-prometheus-server.monitoring.svc.cluster.local
  dashboards:
    default:
      kubernetes-cluster:
        gnetId: 7249
      node-exporter:
        gnetId: 1860
  ingress:
    enabled: true
    ingressClassName: traefik
    hosts: [grafana.CLUSTER.local]
    tls: [...]
```

### 6. Deploy Custom Charts via Flux

```yaml
# HelmRelease pointing to custom charts in git
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: monitoring-stack
  namespace: flux-system
spec:
  chart:
    spec:
      chart: ./pi-fleet/helm/monitoring-stack
      version: "0.1.0"
      sourceRef:
        kind: GitRepository
        name: flux-system
  targetNamespace: monitoring
  install:
    createNamespace: true
```

### 7. Deploy Vault for Secrets Management

```yaml
# HelmRelease for Vault (dev mode for single-node)
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: vault
  namespace: vault
spec:
  chart:
    spec:
      chart: vault
      version: 0.28.1
      sourceRef:
        kind: HelmRepository
        name: hashicorp
  values:
    server:
      dev:
        enabled: true  # Dev mode for single-node (no persistence)
      ui:
        enabled: true
      ingress:
        enabled: true
        ingressClassName: traefik
        hosts:
          - host: vault.CLUSTER.local
        tls:
          - secretName: vault-tls
            hosts:
              - vault.CLUSTER.local
        annotations:
          cert-manager.io/cluster-issuer: selfsigned-cluster-issuer
```

**Important:** Vault runs in dev mode (no persistence). Root token is logged on startup. For production, configure proper storage backend.

### 8. Deploy External Secrets Operator

```yaml
# HelmRelease for External Secrets Operator
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: external-secrets
  namespace: external-secrets
spec:
  chart:
    spec:
      chart: external-secrets
      version: 0.10.7
      sourceRef:
        kind: HelmRepository
        name: external-secrets
  values:
    replicaCount: 1
    resources:
      limits:
        cpu: 200m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

### 9. Configure Vault Access for External Secrets Operator

```bash
# Get Vault root token from pod logs
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
VAULT_TOKEN=$(kubectl logs -n vault $VAULT_POD | grep "Root Token" | awk '{print $NF}')

# Create secret for External Secrets Operator
kubectl create secret generic vault-token \
  --from-literal=token=$VAULT_TOKEN \
  -n external-secrets
```

### 10. Create ClusterSecretStore for Vault

```yaml
# clusters/eldertree/infrastructure/external-secrets/clustersecretstore.yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault
spec:
  provider:
    vault:
      server: http://vault.vault.svc.cluster.local:8200
      path: secret
      version: v2
      auth:
        tokenSecretRef:
          name: vault-token
          key: token
          namespace: external-secrets
```

### 11. Create ExternalSecret Resources

Create ExternalSecret resources for each application that needs secrets:

```yaml
# Example: clusters/eldertree/infrastructure/external-secrets/externalsecrets/canopy-secrets.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: canopy-secrets
  namespace: canopy
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: vault
    kind: ClusterSecretStore
  target:
    name: canopy-secrets
    creationPolicy: Owner
  data:
    - secretKey: postgres-password
      remoteRef:
        key: secret/canopy/postgres
        property: password
    - secretKey: secret-key
      remoteRef:
        key: secret/canopy/app
        property: secret-key
    - secretKey: database-url
      remoteRef:
        key: secret/canopy/database
        property: url
```

### 12. Set Secrets in Vault

```bash
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Set secrets in Vault (External Secrets Operator will sync automatically)
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN=root && vault kv put secret/canopy/postgres password=yourpassword"
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN=root && vault kv put secret/canopy/app secret-key=\$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN=root && vault kv put secret/canopy/database url=postgresql+psycopg://canopy:password@canopy-postgres:5432/canopy"

# Set Grafana admin username and password
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN=root && vault kv put secret/monitoring/grafana adminUser=admin adminPassword=yourpassword"

# Set Pi-hole web password
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN=root && vault kv put secret/pihole/webpassword password=yourpassword"
```

**Secret Paths Structure:**
- `secret/monitoring/grafana` - Grafana admin username and password (`adminUser`, `adminPassword`)
- `secret/pihole/webpassword` - Pi-hole web admin password
- `secret/canopy/postgres` - Canopy PostgreSQL password
- `secret/canopy/app` - Canopy application secret key
- `secret/canopy/database` - Canopy database URL
- `secret/swimto/*` - SwimTO application secrets
- `secret/us-law-severity-map/*` - US Law Severity Map secrets

See `VAULT.md` for complete secret paths and management guide.

## Key Decisions

### ✅ DO

- Use Helm charts for all deployments
- Use K3s built-in local-path-provisioner for storage
- Separate cert-manager from issuers (avoid CRD race)
- Bundle Prometheus + Grafana in single monitoring-stack chart
- Use self-signed certificates for local services
- Commit at each milestone
- Keep documentation concise

### ❌ DON'T

- Don't deploy Longhorn until there's a specific use case
- Don't create multiple separate HelmReleases for related services
- Don't overload with documentation
- Don't commit directly to main/dev branches

## Common Issues & Solutions

### PVC Pending with Wrong StorageClass

**Problem:** PVCs stuck pending with `storageClass: longhorn`

**Solution:**

1. Ensure `storageClassName: local-path` in Helm values
2. Delete existing PVCs: `kubectl delete pvc -n NAMESPACE PVC_NAME`
3. Reconcile HelmRelease: `flux reconcile helmrelease NAME -n NAMESPACE`

### HelmChart Not Found

**Problem:** `invalid chart reference: stat /tmp/.../helm/CHART: no such file or directory`

**Solution:**

- Ensure chart path includes repo prefix: `./pi-fleet/helm/CHART`
- Verify Flux GitRepository is pointing to correct branch
- Check chart exists in git at specified path

### ClusterIssuer CRD Not Found

**Problem:** `no matches for kind "ClusterIssuer" in version "cert-manager.io/v1"`

**Solution:**

- Separate ClusterIssuer into its own Helm chart deployed after cert-manager
- Use HelmRelease dependencies or separate kustomization path

### Kubeconfig Context Issues

**Problem:** `context was not found for specified context: default`

**Solution:**

```bash
# Re-download kubeconfig from cluster
sshpass -p 'PASSWORD' ssh USER@HOST 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/config-CLUSTER
sed -i '' 's/127.0.0.1/HOSTNAME/g' ~/.kube/config-CLUSTER
chmod 600 ~/.kube/config-CLUSTER
```

### ExternalSecret Not Syncing

**Problem:** ExternalSecret shows `SecretSyncedError` status

**Solution:**

1. Check if secret exists in Vault:
```bash
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN=root && vault kv get secret/PATH"
```

2. Verify ClusterSecretStore is configured correctly:
```bash
kubectl get clustersecretstore vault -o yaml
```

3. Check External Secrets Operator logs:
```bash
kubectl logs -n external-secrets deployment/external-secrets
```

4. Ensure vault-token secret exists:
```bash
kubectl get secret vault-token -n external-secrets
```

### Secrets Not Found in Vault

**Problem:** `Secret does not exist` error when syncing

**Solution:**

Create the secret in Vault using the correct path structure:
```bash
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN=root && vault kv put secret/PATH key=value"
```

See `VAULT.md` for complete list of secret paths and setup commands.

## Validation Commands

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/config-eldertree

# Check cluster health
kubectl get nodes
kubectl get pods -A

# Check Flux
flux get sources git
flux get kustomizations
flux get helmreleases -A

# Check certificates
kubectl get clusterissuer
kubectl get certificates -A

# Check ingresses
kubectl get ing -A

# Check storage
kubectl get pvc -A
kubectl get storageclass

# Check Vault
kubectl get pods -n vault
kubectl get ingress -n vault

# Check External Secrets Operator
kubectl get pods -n external-secrets
kubectl get externalsecrets -A
kubectl get clustersecretstore

# Verify secrets are synced
kubectl get secrets -A | grep -E "canopy-secrets|swimto-secrets|pihole-secrets|grafana-admin"

# Check ExternalSecret sync status
kubectl describe externalsecret <name> -n <namespace>
```

## Expected Final State

**Running Pods:**

- flux-system: helm-controller, kustomize-controller, source-controller, notification-controller
- cert-manager: cert-manager, cainjector, webhook
- flux-system: cert-manager-issuers (cert-manager, cainjector, webhook)
- monitoring: grafana, prometheus-server, node-exporter, kube-state-metrics, pushgateway
- vault: vault-0
- external-secrets: external-secrets

**Ingresses:**

- grafana.eldertree.local (HTTPS with self-signed cert)
- prometheus.eldertree.local (HTTPS with self-signed cert)
- vault.eldertree.local (HTTPS with self-signed cert)

**Storage:**

- All PVCs using `local-path` StorageClass
- Prometheus: 8Gi
- Grafana: 2Gi

**Certificates:**

- ClusterIssuer: selfsigned-cluster-issuer (Ready)
- Certificates: grafana-tls, prometheus-tls, vault-tls (Ready)

**Secrets Management:**

- Vault: Running in dev mode (root token in pod logs)
- External Secrets Operator: Syncing secrets from Vault to Kubernetes
- ExternalSecrets: All applications configured to use Vault secrets
- Kubernetes Secrets: Automatically synced from Vault every 24 hours

## Files to Create

1. `NETWORK.md` - Network configuration guide
2. `VAULT.md` - Vault secrets management guide
3. `STATUS.md` - Current cluster state
4. `CHANGELOG.md` - Track all changes
5. `clusters/eldertree/flux-system/gotk-sync.yaml` - Flux sync config
6. `clusters/eldertree/infrastructure/cert-manager/` - cert-manager HelmRelease
7. `clusters/eldertree/infrastructure/issuers/` - cert-manager-issuers HelmRelease
8. `clusters/eldertree/infrastructure/vault/` - Vault HelmRelease
9. `clusters/eldertree/infrastructure/external-secrets/` - External Secrets Operator HelmRelease
10. `clusters/eldertree/infrastructure/external-secrets/clustersecretstore.yaml` - Vault ClusterSecretStore
11. `clusters/eldertree/infrastructure/external-secrets/externalsecrets/*.yaml` - ExternalSecret resources for each application
12. `clusters/eldertree/monitoring/` - monitoring-stack HelmRelease
13. `helm/cert-manager-issuers/` - Custom chart
14. `helm/monitoring-stack/` - Custom chart

## Git Workflow

```bash
# Work in feature branch
git checkout -b infra/CLUSTER-NAME

# Commit at milestones
git add -A
git commit -m "feat: add network docs and flux gitops setup"
git push origin infra/CLUSTER-NAME

# Flux auto-syncs from the branch
flux reconcile source git flux-system
flux reconcile kustomization flux-system
```

## Success Criteria

✅ Flux successfully reconciling from git  
✅ cert-manager deployed and issuing certificates  
✅ Monitoring stack deployed with persistent storage  
✅ Vault deployed and accessible via HTTPS  
✅ External Secrets Operator deployed and syncing secrets  
✅ All ExternalSecret resources syncing successfully  
✅ All Kubernetes secrets synced from Vault  
✅ Grafana accessible via HTTPS with self-signed cert  
✅ Prometheus accessible via HTTPS with self-signed cert  
✅ All applications using secrets from Vault (no hardcoded secrets)  
✅ All documentation concise and actionable  
✅ All changes committed to git with good messages

## Additional Notes

- Cluster may temporarily become unavailable during reconciliations (normal)
- Self-signed certificates will show browser warnings (expected)
- Vault runs in dev mode (no persistence) - root token in pod logs
- External Secrets Operator syncs secrets every 24 hours automatically
- All secrets must be stored in Vault - no hardcoded secrets in deployments
- Default Grafana credentials: admin/admin (update via Vault secret)
- K3s includes Traefik ingress controller by default
- No Longhorn - use local-path-provisioner until advanced storage needed
- Worker nodes can be added later following FLEET.md instructions

## Secrets Management Best Practices

1. **All secrets in Vault** - Single source of truth for all sensitive data
2. **External Secrets Operator** - Automatically syncs Vault secrets to Kubernetes
3. **No hardcoded secrets** - All deployments reference secrets via `secretKeyRef`
4. **Safe defaults** - Config files have development defaults, production uses Vault
5. **Documentation** - All secret paths documented in `VAULT.md`
6. **Placeholder secrets** - Use placeholders for optional secrets (API keys, OAuth)
7. **Regular updates** - Update placeholder secrets with real values when available

## Prompt for AI Assistant

"Set up a K3s cluster on [HARDWARE] with GitOps using Flux. Use custom Helm charts for cert-manager-issuers and a monitoring-stack (Prometheus + Grafana). Deploy Vault for secrets management and External Secrets Operator to automatically sync secrets from Vault to Kubernetes. Deploy everything via Flux HelmReleases pointing to charts in the git repository. Use self-signed certificates for local services. Use K3s built-in local-path-provisioner for storage. Ensure ALL secrets are stored in Vault and ALL applications retrieve secrets from Vault via External Secrets Operator. No hardcoded secrets in deployment files. Keep all documentation concise. Commit at each milestone. Follow the branching strategy in CONTRIBUTING.md. Update CHANGELOG.md as you go. Target structure: clusters/[CLUSTER-NAME]/ for manifests, helm/ for custom charts. See VAULT.md for secrets management guide."
