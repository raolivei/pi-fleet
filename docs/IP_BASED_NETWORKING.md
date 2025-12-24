# IP-Based Network Configuration

This document explains how the cluster is configured for IP-based networking (gigabit network) without DNS resolution.

## Overview

The eldertree cluster uses IP addresses directly instead of DNS names. This configuration affects several components:

1. **Cloudflare Tunnel** - Uses ClusterIP instead of service DNS names
2. **Service Discovery** - Components may need explicit IP addresses
3. **DNS Configuration** - Cluster DNS (CoreDNS) is still available but may not be reliable for all use cases

## Cloudflare Tunnel Configuration

The Cloudflare Tunnel is configured to work with IP-based networking:

### Terraform Configuration

The tunnel ingress rules use Traefik's ClusterIP directly:

```terraform
ingress_rule {
  hostname = "swimto.eldertree.xyz"
  path     = "/"
  service  = "http://10.43.81.2:80"  # Direct ClusterIP, not DNS name
}
```

**Why?** The tunnel container may have DNS resolution issues with Kubernetes service DNS (`traefik.kube-system.svc.cluster.local`), so using the ClusterIP directly is more reliable.

### Tunnel Deployment

The tunnel deployment includes DNS upstream configuration:

```yaml
env:
  - name: TUNNEL_DNS_UPSTREAM
    value: "10.43.0.10,8.8.8.8,1.1.1.1" # Cluster DNS first, then public DNS
```

This ensures:

- Cluster DNS (CoreDNS at `10.43.0.10`) is tried first
- Public DNS (Google and Cloudflare) as fallback
- Works even if cluster DNS is unavailable

## Finding Service IPs

### Traefik ClusterIP

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get svc traefik -n kube-system -o jsonpath='{.spec.clusterIP}'
```

### CoreDNS ClusterIP

```bash
kubectl get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}'
```

### Any Service ClusterIP

```bash
kubectl get svc <service-name> -n <namespace> -o jsonpath='{.spec.clusterIP}'
```

## Updating Configuration

### If Traefik ClusterIP Changes

1. **Get the new IP:**

   ```bash
   TRAEFIK_IP=$(kubectl get svc traefik -n kube-system -o jsonpath='{.spec.clusterIP}')
   echo "New Traefik IP: $TRAEFIK_IP"
   ```

2. **Update Terraform:**

   ```bash
   cd pi-fleet/terraform
   # Edit cloudflare.tf and replace all instances of 10.43.81.2 with $TRAEFIK_IP
   ```

3. **Apply changes:**
   ```bash
   terraform apply
   ```

### If CoreDNS IP Changes

Update the tunnel deployment:

```bash
cd pi-fleet/clusters/eldertree/dns-services/cloudflare-tunnel
# Edit deployment.yaml and update TUNNEL_DNS_UPSTREAM with new CoreDNS IP
```

## Testing Connectivity

### Test from within cluster

```bash
# Test Traefik connectivity
kubectl run -it --rm test-curl --image=curlimages/curl:latest --restart=Never -- \
  curl -s -H "Host: swimto.eldertree.xyz" http://10.43.81.2:80 | head -20

# Test DNS resolution (if available)
kubectl run -it --rm test-dns --image=busybox:latest --restart=Never -- \
  nslookup traefik.kube-system.svc.cluster.local
```

### Test tunnel connectivity

```bash
# Check tunnel logs
kubectl logs -n cloudflare-tunnel -l app=cloudflared --tail=50

# Test external access
curl -I https://swimto.eldertree.xyz
```

## Troubleshooting

### Tunnel can't reach backend

1. **Verify Traefik IP matches config:**

   ```bash
   kubectl get svc traefik -n kube-system -o jsonpath='{.spec.clusterIP}'
   grep "10.43.81.2" pi-fleet/terraform/cloudflare.tf
   ```

2. **Test connectivity from tunnel pod:**

   ```bash
   kubectl exec -n cloudflare-tunnel -l app=cloudflared -- \
     curl -s -H "Host: swimto.eldertree.xyz" http://10.43.81.2:80 | head -10
   ```

3. **Check tunnel DNS configuration:**
   ```bash
   kubectl get deployment cloudflared -n cloudflare-tunnel -o yaml | grep TUNNEL_DNS_UPSTREAM
   ```

### DNS resolution issues

If components need DNS resolution:

1. **Verify CoreDNS is running:**

   ```bash
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   ```

2. **Check CoreDNS IP:**

   ```bash
   kubectl get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}'
   ```

3. **Update DNS upstream in components** that need it (like tunnel deployment)

## Related Documentation

- [Cloudflare Tunnel Troubleshooting](./CLOUDFLARE_TUNNEL_TROUBLESHOOTING.md)
- [DNS Troubleshooting](./DNS_TROUBLESHOOTING.md)
