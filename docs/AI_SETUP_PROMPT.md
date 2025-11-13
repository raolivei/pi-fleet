# AI Prompt: K3s Cluster Setup with GitOps

Use this prompt to replicate the eldertree cluster setup on similar infrastructure.

## Objective

Set up a production-ready single-node K3s cluster on a Raspberry Pi with:

- GitOps-based deployment using Flux
- Monitoring stack (Prometheus + Grafana)
- Certificate management with self-signed TLS
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
├── STATUS.md          # Current state
└── CHANGELOG.md       # Changes tracking
```

## Requirements

1. **Use Helm charts as much as possible** - All deployments should be Helm-based
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
```

## Expected Final State

**Running Pods:**

- flux-system: helm-controller, kustomize-controller, source-controller, notification-controller
- cert-manager: cert-manager, cainjector, webhook
- flux-system: cert-manager-issuers (cert-manager, cainjector, webhook)
- monitoring: grafana, prometheus-server, node-exporter, kube-state-metrics, pushgateway

**Ingresses:**

- grafana.eldertree.local (HTTPS with self-signed cert)
- prometheus.eldertree.local (HTTPS with self-signed cert)

**Storage:**

- All PVCs using `local-path` StorageClass
- Prometheus: 8Gi
- Grafana: 2Gi

**Certificates:**

- ClusterIssuer: selfsigned-cluster-issuer (Ready)
- Certificates: grafana-tls, prometheus-tls (Ready)

## Files to Create

1. `NETWORK.md` - Network configuration guide
2. `STATUS.md` - Current cluster state
3. `CHANGELOG.md` - Track all changes
4. `clusters/eldertree/flux-system/gotk-sync.yaml` - Flux sync config
5. `clusters/eldertree/infrastructure/cert-manager/` - cert-manager HelmRelease
6. `clusters/eldertree/infrastructure/issuers/` - cert-manager-issuers HelmRelease
7. `clusters/eldertree/monitoring/` - monitoring-stack HelmRelease
8. `helm/cert-manager-issuers/` - Custom chart
9. `helm/monitoring-stack/` - Custom chart

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
✅ Grafana accessible via HTTPS with self-signed cert  
✅ Prometheus accessible via HTTPS with self-signed cert  
✅ All documentation concise and actionable  
✅ All changes committed to git with good messages

## Additional Notes

- Cluster may temporarily become unavailable during reconciliations (normal)
- Self-signed certificates will show browser warnings (expected)
- Default Grafana credentials: admin/admin
- K3s includes Traefik ingress controller by default
- No Longhorn - use local-path-provisioner until advanced storage needed
- Worker nodes can be added later following FLEET.md instructions

## Prompt for AI Assistant

"Set up a K3s cluster on [HARDWARE] with GitOps using Flux. Use custom Helm charts for cert-manager-issuers and a monitoring-stack (Prometheus + Grafana). Deploy everything via Flux HelmReleases pointing to charts in the git repository. Use self-signed certificates for local services. Use K3s built-in local-path-provisioner for storage. Keep all documentation concise. Commit at each milestone. Follow the branching strategy in CONTRIBUTING.md. Update CHANGELOG.md as you go. Target structure: clusters/[CLUSTER-NAME]/ for manifests, helm/ for custom charts."
