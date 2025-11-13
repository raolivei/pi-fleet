# Eldertree Cluster Status

## Cluster Information

- **Name**: eldertree
- **Type**: Single-node K3s cluster
- **Node**: eldertree (192.168.2.83)
- **K3s Version**: v1.33.5+k3s1
- **Helm Version**: v4.0.0 (compatible)

## Deployed Components

### Infrastructure

- ✅ **Flux GitOps** - Automatic deployment from git
- ✅ **cert-manager** - TLS certificate management
- ✅ **cert-manager-issuers** - Self-signed ClusterIssuer configured
- ✅ **Pi-hole** - DNS server with custom DNS rewrites for *.eldertree.local

### Monitoring

- ✅ **Prometheus** - Metrics collection and storage
- ✅ **Grafana** - Monitoring dashboards (admin/admin)
- ✅ **Node Exporter** - Node-level metrics
- ✅ **Kube State Metrics** - Kubernetes object metrics

### Storage

- ✅ **local-path-provisioner** - Built-in K3s dynamic storage

### Ingress

- ✅ **Traefik** - Built-in K3s ingress controller
- ✅ **TLS** - Self-signed certificates via cert-manager

## Applications

### Monitoring

- **Grafana**: https://grafana.eldertree.local (admin/admin)
- **Prometheus**: https://prometheus.eldertree.local

### Finance

- **Canopy**: https://canopy.eldertree.local - Personal finance dashboard

### DNS

- **Pi-hole**: https://pihole.eldertree.local - DNS server with automatic *.eldertree.local resolution

## Network Configuration

### Option 1: Pi-hole DNS (Recommended - Automatic)

Pi-hole automatically resolves `*.eldertree.local` domains via Kubernetes ConfigMap:
- See [docs/DNS_SETUP.md](./docs/DNS_SETUP.md) for instructions
- Or run: `./scripts/setup-pihole-dns.sh`
- Configure your router or device DNS to use: `192.168.2.83:30053`

### Option 2: Manual /etc/hosts

Add to `/etc/hosts`:

```
192.168.2.83  eldertree
192.168.2.83  grafana.eldertree.local
192.168.2.83  prometheus.eldertree.local
192.168.2.83  canopy.eldertree.local
192.168.2.83  pihole.eldertree.local
192.168.2.83  vault.eldertree.local
```

## Validation

```bash
# Check cluster
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes

# Check deployments
kubectl get pods -A
kubectl get helmreleases -A
kubectl get ingresses -A

# Check certificates
kubectl get clusterissuer
kubectl get certificates -A
```

## Next Steps

- Configure static IP reservation in router for 192.168.2.83
- Import Kubernetes dashboards into Grafana
- Set up alerts in Prometheus (when needed)
- Add worker nodes (when needed)
