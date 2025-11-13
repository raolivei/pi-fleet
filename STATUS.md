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

## Network Configuration

Add to `/etc/hosts`:

```
192.168.2.83  eldertree
192.168.2.83  grafana.eldertree.local
192.168.2.83  prometheus.eldertree.local
192.168.2.83  canopy.eldertree.local
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
