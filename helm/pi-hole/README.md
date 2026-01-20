# Pi-hole Helm Chart

Helm chart for deploying Pi-hole DNS server with ad-blocking capabilities in Kubernetes.

## Important Configuration Notes

### Preventing Port Conflicts

This chart is configured to prevent common port conflicts:

1. **hostNetwork is explicitly disabled**: The deployment template sets `hostNetwork: false` to prevent port 53 conflicts on the host. This allows kube-vip LoadBalancer to work properly.

2. **k3s ServiceLB is disabled**: The service includes the annotation `svc.k3s.cattle.io/loadbalancer-proxy: "false"` to prevent k3s from creating `svclb-pi-hole` DaemonSet pods that would conflict with port 53.

3. **kube-vip LoadBalancer**: The service uses kube-vip for external access (192.168.2.201), which routes traffic through the LoadBalancer service without requiring host network access.

### Common Issues and Solutions

#### Pods Stuck in Pending State

If Pi-hole pods are stuck in `Pending` with errors about port conflicts:

1. **Check for hostNetwork**: Verify the deployment doesn't have `hostNetwork: true`:
   ```bash
   kubectl get deployment pi-hole -n pihole -o jsonpath='{.spec.template.spec.hostNetwork}'
   ```
   This should be empty or `false`. If it's `true`, the Helm chart needs to be updated.

2. **Check for svclb DaemonSets**: Look for conflicting ServiceLB pods:
   ```bash
   kubectl get daemonset -n kube-system | grep svclb-pi-hole
   ```
   If found, delete them:
   ```bash
   kubectl delete daemonset -n kube-system svclb-pi-hole-*
   ```

3. **Verify service annotation**: Ensure the service has the correct annotation:
   ```bash
   kubectl get svc pi-hole -n pihole -o jsonpath='{.metadata.annotations.svc\.k3s\.cattle\.io/loadbalancer-proxy}'
   ```
   This should return `false`.

#### Ad Blocking Not Working

1. **Verify blocking is enabled**: Check the environment variable:
   ```bash
   kubectl exec -n pihole <pod-name> -c pihole -- printenv | grep FTLCONF_blocking_enabled
   ```
   Should show `FTLCONF_blocking_enabled=true`

2. **Check Pi-hole status**:
   ```bash
   kubectl exec -n pihole <pod-name> -c pihole -- pihole status
   ```
   Should show "Pi-hole blocking is enabled"

3. **Update gravity (block lists)**:
   ```bash
   kubectl exec -n pihole <pod-name> -c pihole -- pihole -g
   ```

## Configuration

### Service Type

The default service type is `LoadBalancer` with kube-vip. To use NodePort instead:

```yaml
service:
  type: NodePort
```

### DNS Configuration

Default upstream DNS servers are Google DNS (8.8.8.8) and Cloudflare (1.1.1.1). To change:

```yaml
config:
  dns1: 8.8.8.8
  dns2: 1.1.1.1
```

## Resources

- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [kube-vip Documentation](https://kube-vip.io/)

