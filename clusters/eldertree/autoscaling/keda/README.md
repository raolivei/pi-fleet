# KEDA - Kubernetes Event Driven Autoscaler

KEDA is a Kubernetes-based Event Driven Autoscaler. With KEDA, you can drive the scaling of any container in Kubernetes based on the number of events needing to be processed.

## Features

- **Event-driven autoscaling**: Scale based on external metrics (queues, databases, custom metrics, etc.)
- **Built on top of HPA**: Works with Kubernetes Horizontal Pod Autoscaler
- **Multiple scalers**: Supports 50+ scalers including:
  - Prometheus
  - Redis
  - PostgreSQL
  - RabbitMQ
  - Apache Kafka
  - AWS SQS, CloudWatch
  - Azure Queue, Event Hub
  - GCP Pub/Sub
  - And many more

## Components Deployed

1. **KEDA Operator**: Main controller that manages ScaledObjects and ScaledJobs
2. **Metrics Server**: Exposes metrics to Kubernetes Metrics API
3. **Admission Webhooks**: Validates and mutates KEDA resources

## Example Usage

### Scale based on Prometheus metrics

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: prometheus-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: my-deployment
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus-stack.observability.svc.cluster.local:9090
        metricName: http_requests_total
        threshold: "100"
        query: sum(rate(http_requests_total{job="my-app"}[2m]))
```

### Scale based on Redis list length

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: redis-scaledobject
spec:
  scaleTargetRef:
    name: worker-deployment
  minReplicaCount: 0
  maxReplicaCount: 20
  triggers:
    - type: redis
      metadata:
        address: redis-service:6379
        listName: mylist
        listLength: "5"
```

### Scale a CronJob based on events

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledJob
metadata:
  name: my-scaled-job
spec:
  jobTargetRef:
    template:
      spec:
        containers:
          - name: worker
            image: my-worker:latest
  triggers:
    - type: rabbitmq
      metadata:
        queueName: tasks
        host: amqp://user:pass@rabbitmq:5672
        queueLength: "5"
```

## Monitoring

KEDA exposes Prometheus metrics at:

- Operator: `http://keda-operator.keda.svc.cluster.local:8080/metrics`
- Metrics Server: `http://keda-metrics-apiserver.keda.svc.cluster.local:8080/metrics`

## Verification

After deployment, verify KEDA is running:

```bash
# Check KEDA pods
kubectl get pods -n keda

# Check KEDA CRDs
kubectl get crd | grep keda

# Check KEDA API service
kubectl get apiservice | grep keda
```

## Resources

- [KEDA Documentation](https://keda.sh/docs/)
- [Scalers List](https://keda.sh/docs/scalers/)
- [GitHub Repository](https://github.com/kedacore/keda)
