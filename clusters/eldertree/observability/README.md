# Observability Stack

This directory contains the observability components for the eldertree cluster.

## Components

### KEDA - Kubernetes Event Driven Autoscaler

**Status**: ✅ Deployed via Flux GitOps

KEDA enables event-driven autoscaling for Kubernetes workloads based on external metrics.

**Deployed Components:**

- **KEDA Operator**: Main controller managing ScaledObjects and ScaledJobs
- **Metrics Server**: Exposes external metrics to Kubernetes Metrics API
- **Admission Webhooks**: Validates and mutates KEDA resources

**Namespace**: `keda`

**Version**: 2.15.1

**Resources:**

- Operator: 100m CPU / 100Mi RAM (request), 1000m CPU / 1000Mi RAM (limit)
- Metrics Server: 100m CPU / 100Mi RAM (request), 1000m CPU / 1000Mi RAM (limit)
- Webhooks: 100m CPU / 100Mi RAM (request), 1000m CPU / 1000Mi RAM (limit)

### Verification Commands

Once the cluster connection is stable, verify the deployment:

```bash
# Check KEDA namespace
kubectl get namespace keda

# Check KEDA pods
kubectl get pods -n keda

# Expected output:
# NAME                                               READY   STATUS    RESTARTS   AGE
# keda-admission-webhooks-xxx                        1/1     Running   0          Xm
# keda-operator-xxx                                  1/1     Running   0          Xm
# keda-operator-metrics-apiserver-xxx                1/1     Running   0          Xm

# Check KEDA HelmRelease
kubectl get helmrelease -n keda

# Check KEDA CRDs
kubectl get crd | grep keda
# Expected: scaledjobs.keda.sh, scaledobjects.keda.sh, triggerauthentications.keda.sh, etc.

# Check KEDA API service
kubectl get apiservice | grep keda
```

### Using KEDA

Example ScaledObject for Prometheus-based autoscaling:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: my-app-scaler
  namespace: default
spec:
  scaleTargetRef:
    name: my-app-deployment
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus-server.monitoring.svc:9090
        metricName: http_requests_per_second
        threshold: "100"
        query: |
          sum(rate(http_requests_total{app="my-app"}[2m]))
```

### Monitoring

KEDA exposes Prometheus metrics:

- Operator metrics: `http://keda-operator.keda.svc.cluster.local:8080/metrics`
- Metrics Server: `http://keda-metrics-apiserver.keda.svc.cluster.local:8080/metrics`

### Documentation

- [KEDA Documentation](https://keda.sh/docs/)
- [Scalers Reference](https://keda.sh/docs/scalers/)
- [KEDA GitHub](https://github.com/kedacore/keda)

## Future Additions

Consider adding these observability components:

- [ ] **Metrics Server** - Core metrics for CPU/Memory based HPA
- [ ] **Kubernetes Dashboard** - Web UI for cluster management
- [ ] **Netdata** - Real-time performance monitoring
- [ ] **Grafana Agent** - Metrics collection and forwarding
- [ ] **cAdvisor** - Container resource usage and performance
- [ ] **Loki** - Log aggregation
- [ ] **Tempo** - Distributed tracing


