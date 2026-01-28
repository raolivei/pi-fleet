# Vertical Pod Autoscaler (VPA)

VPA automatically adjusts CPU and memory requests for pods based on historical usage.

## Current Configuration

- **Recommender**: Enabled - provides resource recommendations
- **Updater**: Disabled - does not automatically restart pods
- **Admission Controller**: Disabled - does not mutate pods at creation

This "recommendation-only" mode allows you to:
1. View VPA recommendations without automatic changes
2. Manually apply recommendations when ready
3. Gradually enable auto-updates once confident

## Usage

### View Recommendations

```bash
# List all VPAs
kubectl get vpa -A

# Get detailed recommendations for a specific VPA
kubectl describe vpa swimto-api-vpa -n swimto
```

### Create VPA for a Deployment

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app-vpa
  namespace: my-namespace
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Off"  # Recommendations only
  resourcePolicy:
    containerPolicies:
      - containerName: "*"
        minAllowed:
          cpu: 50m
          memory: 64Mi
        maxAllowed:
          cpu: 1000m
          memory: 1Gi
```

### Update Modes

| Mode | Behavior |
|------|----------|
| `Off` | Recommendations only, no automatic updates |
| `Initial` | Only set resources at pod creation |
| `Recreate` | Evict pods to apply new resources |
| `Auto` | Apply updates with minimal disruption |

## Enabling Auto-Updates (Future)

To enable automatic resource updates, modify the HelmRelease:

```yaml
values:
  updater:
    enabled: true
  admissionController:
    enabled: true
```

Then change VPA updateMode from "Off" to "Auto".

## Resources

- [VPA Documentation](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
- [Fairwinds VPA Chart](https://github.com/FairwindsOps/charts/tree/master/stable/vpa)
