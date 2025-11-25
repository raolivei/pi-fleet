# Multi-Node Storage Configuration

## Overview

The eldertree cluster is designed to support multiple nodes with different storage types:

- **Main Node (eldertree)**: SATA/NVMe drive for high-performance workloads
- **Worker Nodes**: SD card storage for standard workloads

## Storage Classes

### Available Storage Classes

1. **`local-path-nvme`** - For high-performance workloads on the main node
   - Uses SATA/NVMe drive at `/mnt/nvme/storage` or `/mnt/sata/storage`
   - Recommended for: Databases, Vault, high-I/O applications

2. **`local-path-sd`** - For standard workloads on worker nodes
   - Uses SD card storage at `/var/lib/rancher/k3s/storage`
   - Recommended for: General applications, caches, temporary data

3. **`local-path`** (default) - Uses node-specific paths based on configuration
   - Main node: SATA/NVMe drive
   - Worker nodes: SD card storage

## Local-Path Provisioner Configuration

The local-path provisioner uses a ConfigMap (`local-path-config` in `kube-system`) to determine which storage path to use based on the node name.

### Current Configuration

The ConfigMap defines node-specific paths:

```json
{
  "nodePathMap": [
    {
      "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
      "paths": ["/var/lib/rancher/k3s/storage"]
    },
    {
      "node": "eldertree",
      "paths": ["/mnt/nvme/storage", "/mnt/sata/storage"]
    }
  ]
}
```

### Updating Configuration for New Worker Nodes

When adding worker nodes, update the ConfigMap to include their node names:

```bash
# Get current configuration
kubectl get configmap local-path-config -n kube-system -o jsonpath='{.data.config\.json}' | jq .

# Update with new worker node
kubectl patch configmap local-path-config -n kube-system \
  --type merge \
  -p '{"data":{"config.json":"{\"nodePathMap\":[{\"node\":\"DEFAULT_PATH_FOR_NON_LISTED_NODES\",\"paths\":[\"/var/lib/rancher/k3s/storage\"]},{\"node\":\"eldertree\",\"paths\":[\"/mnt/nvme/storage\",\"/mnt/sata/storage\"]},{\"node\":\"worker-node-1\",\"paths\":[\"/var/lib/rancher/k3s/storage\"]}]}"}}'
```

Or use the helper script:

```bash
./scripts/storage/update-local-path-config.sh
```

## Using Storage Classes

### For High-Performance Workloads (Main Node)

Use `local-path-nvme` to ensure storage is on the SATA/NVMe drive:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: myapp
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path-nvme
```

### For Standard Workloads (Worker Nodes)

Use `local-path-sd` to ensure storage is on SD card:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cache-pvc
  namespace: myapp
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-path-sd
```

### Node Affinity (Optional)

To ensure pods are scheduled on specific nodes, use node selectors or node affinity:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""  # Main node
      # OR for worker nodes:
      # nodeSelector:
      #   node-role.kubernetes.io/worker: ""
      containers:
      - name: app
        image: myapp:latest
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: myapp-pvc
```

## Storage Path Setup

### Main Node (eldertree)

The SATA/NVMe drive should be mounted at:
- `/mnt/nvme/storage` (for NVMe drives)
- `/mnt/sata/storage` (for SATA drives)

See [NVME_STORAGE_SETUP.md](NVME_STORAGE_SETUP.md) for setup instructions.

### Worker Nodes

SD card storage is automatically available at:
- `/var/lib/rancher/k3s/storage`

No additional setup required - this is the default K3s storage location.

## Verification

### Check Storage Classes

```bash
kubectl get storageclass
```

### Check Local-Path Configuration

```bash
kubectl get configmap local-path-config -n kube-system -o yaml | grep -A 10 config.json
```

### Verify PVC Location

```bash
# List all PVCs
kubectl get pvc --all-namespaces

# Check which node a PVC is bound to
kubectl get pv -o wide

# Check actual storage location on node
# (SSH to the node and check the path)
```

## Migration

When adding worker nodes:

1. **Update ConfigMap** with new node names (see above)
2. **Existing PVCs** will continue using their current nodes
3. **New PVCs** will use the appropriate storage based on:
   - Storage class selection
   - Node where pod is scheduled
   - Node-specific paths in ConfigMap

## Best Practices

1. **Use explicit storage classes** (`local-path-nvme` or `local-path-sd`) for clarity
2. **Use node selectors** when you need specific node placement
3. **Monitor storage usage** on each node separately
4. **Backup critical data** regularly, especially from main node
5. **Document node names** when adding new nodes to ConfigMap

## Troubleshooting

### PVC Stuck in Pending

- Check if storage class exists: `kubectl get storageclass`
- Check node paths exist: SSH to node and verify paths
- Check ConfigMap configuration: `kubectl get configmap local-path-config -n kube-system -o yaml`

### Wrong Storage Location

- Verify node name in ConfigMap matches actual node name: `kubectl get nodes`
- Check which node pod is scheduled on: `kubectl get pod -o wide`
- Verify storage class is correct in PVC spec

### Storage Class Not Found

- Apply storage class: `kubectl apply -f clusters/eldertree/core-infrastructure/storage-class-*.yaml`
- Check if provisioner is running: `kubectl get pods -n kube-system | grep local-path`

