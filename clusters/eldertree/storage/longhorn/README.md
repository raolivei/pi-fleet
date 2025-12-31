# Longhorn Storage for ElderTree Cluster

Distributed block storage for the ElderTree k3s cluster running on Raspberry Pi ARM64 nodes with NVMe storage.

## Architecture

Longhorn provides distributed block storage across 3 Raspberry Pi nodes, each with NVMe M.2 storage. Storage is provisioned at `/mnt/longhorn` on each node using ext4 filesystem. Default replica count of 2 with hard anti-affinity ensures data survives single node failures.

### Components

- **Longhorn Manager**: Orchestrates volume lifecycle
- **Longhorn Engine**: Handles I/O operations per volume
- **Longhorn Instance Manager**: Manages engine/replica instances
- **Longhorn CSI Driver**: Kubernetes integration
- **Longhorn UI**: Web-based management interface

### Storage Flow

```
PVC Request → Longhorn CSI → Longhorn Manager → Create Volume (2 replicas, different nodes) → Mount to Pod
```

### Key Features

- **Default Replica Count**: 2 (survives single node failure)
- **Hard Anti-Affinity**: Replicas must be on different nodes
- **Storage Path**: `/mnt/longhorn` on each node
- **Filesystem**: ext4
- **Architecture**: ARM64 optimized for Raspberry Pi

## Installation

### Prerequisites

#### 1. Kernel Modules (on all nodes)

Install and load required kernel modules:

```bash
sudo apt-get update
sudo apt-get install -y open-iscsi
sudo modprobe open-iscsi
```

Verify modules are loaded:

```bash
lsmod | grep -E 'iscsi|nvme'
```

#### 2. Mount Setup (on all nodes)

Create the Longhorn storage directory:

```bash
sudo mkdir -p /mnt/longhorn
```

Ensure sufficient space (recommend 50GB+ free). The directory should be on a separate partition or mount point, not the root filesystem.

#### 3. Filesystem Preparation (on all nodes)

If using a dedicated partition:

```bash
# Identify NVMe device
lsblk

# Format partition (adjust device name)
sudo mkfs.ext4 -L longhorn /dev/nvme0n1pX

# Mount
sudo mount /dev/nvme0n1pX /mnt/longhorn

# Add to /etc/fstab for persistence
echo "UUID=$(blkid -o value -s UUID /dev/nvme0n1pX) /mnt/longhorn ext4 defaults 0 2" | sudo tee -a /etc/fstab
```

Or use UUID:

```bash
UUID=<uuid> /mnt/longhorn ext4 defaults 0 2
```

#### 4. k3s Prerequisites

- Ensure k3s is running on all nodes
- Verify node labels are set correctly
- Check network connectivity between nodes

#### 5. Flux Prerequisites

- Flux must be bootstrapped and operational
- Git repository must be accessible
- Flux controllers must be running

### Adding New Nodes

When adding a new node to the cluster (e.g., node-2), Longhorn will automatically discover and use it for replica placement once the node is properly configured.

**For new nodes**, use the Ansible playbook to set up Longhorn prerequisites:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible
ansible-playbook playbooks/setup-longhorn-node.yml --limit node-2
```

This playbook:

- Installs `open-iscsi` package
- Loads iscsi kernel module
- Creates `/mnt/longhorn` directory
- Optionally formats and mounts a dedicated partition (if `longhorn_device` is specified)

**Optional: Use dedicated partition**:

```bash
ansible-playbook playbooks/setup-longhorn-node.yml \
  --limit node-2 \
  -e "longhorn_device=/dev/nvme0n1p3"
```

After the node joins the cluster, Longhorn will automatically:

- Discover the new node
- Register the disk at `/mnt/longhorn`
- Make it available for replica placement
- Respect anti-affinity rules (replicas on different nodes)

See `pi-fleet/docs/SETUP_NODE_2_PROMPT.md` for complete node setup instructions.

### Pre-flight Checks

Run the pre-flight check script:

```bash
cd clusters/eldertree/storage/longhorn
./install.sh
```

This script verifies:

- Kernel modules are loaded
- Mount points are configured
- Disk space is sufficient
- k3s is running
- Flux is operational
- Node labels are correct

### Deployment

Longhorn is deployed via **Flux GitOps** using the official Helm chart. This is the recommended best practice for declarative management and automated updates.

#### Deployment Steps

1. **Commit manifests to git repository**:

   ```bash
   git add clusters/eldertree/storage/longhorn/
   git commit -m "feat: add Longhorn storage for ElderTree cluster"
   git push
   ```

2. **Flux will automatically deploy**:

   - Monitor deployment: `kubectl get pods -n longhorn-system -w`
   - Check HelmRelease status: `kubectl get helmrelease -n longhorn-system`

3. **Verify installation**:
   ```bash
   ./verify.sh
   ```

#### Manual Verification

```bash
# Check pods
kubectl get pods -n longhorn-system

# Check HelmRelease
kubectl get helmrelease longhorn -n longhorn-system

# Check StorageClass
kubectl get storageclass longhorn

# Access Longhorn UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Open http://localhost:8080
```

## Configuration

### Default Settings

Configured via `helmrelease.yaml`:

- **Replica Count**: 2
- **Anti-Affinity**: Hard requirement (replicas on different nodes)
- **Default Data Path**: `/mnt/longhorn`
- **Filesystem**: ext4
- **Storage Class**: Manual selection (not default)

### Node Configuration

After installation, verify all nodes are schedulable:

```bash
kubectl get nodes
kubectl get nodes -o yaml | grep -A 5 longhorn
```

In Longhorn UI:

1. Go to **Node** section
2. Verify all 3 nodes are listed
3. Confirm disk registration at `/mnt/longhorn`
4. Ensure scheduling is enabled on all nodes

### Storage Class

The Longhorn StorageClass is created automatically but is **not set as default**. To use it, specify in PVC:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

## Backup Configuration

### SanDisk Extreme SD Drive Setup

The SanDisk Extreme SD drive is mounted on the eldertree control plane node and shared via NFS for Longhorn backups.

#### Automated Setup

Run the backup setup script on the eldertree node:

```bash
cd clusters/eldertree/storage/longhorn
sudo ./backup-setup.sh
```

The script will:

1. Detect and identify the SD drive
2. Format the drive (if needed) as ext4
3. Mount to `/mnt/longhorn-backup`
4. Install and configure NFS server
5. Export the mount point via NFS
6. Provide Longhorn backup target configuration

#### Manual Setup

1. **Identify SD Drive**:

   ```bash
   lsblk
   # Typically appears as /dev/sda or /dev/sdb
   ```

2. **Format SD Drive** (if needed):

   ```bash
   sudo mkfs.ext4 -L longhorn-backup /dev/sdX
   ```

3. **Mount SD Drive**:

   ```bash
   sudo mkdir -p /mnt/longhorn-backup
   sudo mount /dev/sdX /mnt/longhorn-backup

   # Add to /etc/fstab
   UUID=$(blkid -o value -s UUID /dev/sdX)
   echo "UUID=$UUID /mnt/longhorn-backup ext4 defaults 0 2" | sudo tee -a /etc/fstab
   ```

4. **Install NFS Server**:

   ```bash
   sudo apt-get update
   sudo apt-get install -y nfs-kernel-server
   ```

5. **Configure NFS Export**:

   ```bash
   # Add to /etc/exports
   echo "/mnt/longhorn-backup *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports

   # Apply exports
   sudo exportfs -ra

   # Start NFS server
   sudo systemctl enable --now nfs-kernel-server
   ```

6. **Configure Longhorn Backup Target**:

   Get eldertree node IP:

   ```bash
   hostname -I | awk '{print $1}'
   ```

   **Option 1: Via Longhorn UI**

   - Port-forward: `kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80`
   - Open http://localhost:8080
   - Go to **Settings → General → Backup Target**
   - Set to: `nfs://<eldertree-ip>:/mnt/longhorn-backup`

   **Option 2: Via kubectl**

   ```bash
   kubectl -n longhorn-system create -f - <<EOF
   apiVersion: longhorn.io/v1beta2
   kind: Setting
   metadata:
     name: backup-target
     namespace: longhorn-system
   value: "nfs://<eldertree-ip>:/mnt/longhorn-backup"
   EOF
   ```

7. **Test Backup**:
   - Create a test volume in Longhorn UI
   - Create a snapshot
   - Create a backup
   - Verify backup appears in `/mnt/longhorn-backup` on eldertree node
   - Test restore from backup

### Security Considerations

- NFS export uses `*` (all hosts) - acceptable for local network
- Consider restricting to cluster node IPs if needed: `/mnt/longhorn-backup 192.168.2.0/24(rw,sync,no_subtree_check,no_root_squash)`
- Ensure proper filesystem permissions on mount point

### Alternative Backup Targets

Longhorn also supports:

- **S3-compatible storage**: `s3://bucket@region/prefix?accessKey=...&secretKey=...`
- **MinIO**: Deploy MinIO in cluster and use S3 endpoint
- **Azure Blob Storage**: `azblob://container@account/prefix?accountKey=...`

## Validation & Testing

### Health Checks

Run the verification script:

```bash
./verify.sh
```

This script verifies:

- Longhorn components are running
- StorageClass exists
- Node disk registration
- Test PVC creation
- Replica distribution (requires UI check)

### Replica Distribution Verification

1. Access Longhorn UI: `kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80`
2. Go to **Volume** section
3. Select a volume
4. Verify:
   - Volume has 2 replicas
   - Replicas are on different nodes
   - No two replicas share the same node

### Node Failure Simulation

Test Longhorn's resilience by simulating a node failure:

1. **Create a test pod with PVC**:

   ```bash
   kubectl run test-pod --image=busybox --rm -it --restart=Never \
     --overrides='{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"longhorn-test-pvc"}}],"containers":[{"name":"test-pod","image":"busybox","volumeMounts":[{"mountPath":"/data","name":"data"}]}]}}'
   ```

2. **Identify the node running the pod**:

   ```bash
   kubectl get pod test-pod -o wide
   ```

3. **Cordon the node** (prevent new pods):

   ```bash
   kubectl cordon <node-name>
   ```

4. **Drain the node** (simulate failure):

   ```bash
   kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
   ```

5. **Verify volume rebuild**:

   - Check Longhorn UI for volume status
   - Verify replicas are rebuilt on remaining nodes
   - Check pod reschedules to another node

6. **Restore the node**:
   ```bash
   kubectl uncordon <node-name>
   ```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n longhorn-system

# Check pod logs
kubectl logs -n longhorn-system -l app=longhorn-manager

# Check events
kubectl get events -n longhorn-system --sort-by='.lastTimestamp'
```

### Volume Stuck

```bash
# Check volume status
kubectl get volumes.longhorn.io -n longhorn-system

# Check replica status
kubectl get replicas.longhorn.io -n longhorn-system

# Check engine status
kubectl get engines.longhorn.io -n longhorn-system
```

### Disk Registration Issues

```bash
# Check node disk status in Longhorn UI
# Or via kubectl
kubectl get nodes -o yaml | grep -A 10 longhorn

# Verify mount point exists on node
# SSH to node and check:
ls -la /mnt/longhorn
df -h /mnt/longhorn
```

### Backup Issues

```bash
# Check NFS export
showmount -e localhost

# Check NFS server status
systemctl status nfs-kernel-server

# Check backup target setting
kubectl get setting backup-target -n longhorn-system -o yaml

# Test NFS mount manually
sudo mount -t nfs localhost:/mnt/longhorn-backup /tmp/test
```

## Explicit Non-goals

This setup does **NOT** protect against:

- **Accidental PVC/PV deletion**: Use backups and proper RBAC
- **Cluster-wide corruption**: Use external backups
- **Simultaneous failure of 2+ nodes**: Only 2 replicas configured
- **Data loss from application bugs**: Application-level issue
- **Network partition scenarios**: Split-brain possible
- **Physical damage to multiple nodes**: Hardware failure

## Resource Limits

Longhorn is configured with resource limits optimized for Raspberry Pi:

- **Manager**: 100m-500m CPU, 128Mi-512Mi memory
- **Engine**: 50m-200m CPU, 64Mi-256Mi memory
- **Instance Manager**: 50m-200m CPU, 64Mi-256Mi memory
- **CSI Drivers**: 50m-200m CPU, 64Mi-128Mi memory
- **UI**: 50m-200m CPU, 64Mi-128Mi memory

Adjust in `helmrelease.yaml` if needed.

## Integration

### Flux Kustomization

Add to `core-infrastructure/kustomization.yaml` or create separate `storage/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - storage/longhorn
```

### Deployment Order

Longhorn is deployed in **Phase 1: Core Infrastructure** (no dependencies). Update `DEPLOYMENT_ORDER.md`:

```markdown
### Phase 1: Core Infrastructure (No Dependencies)

1. **cert-manager** - TLS certificate management
2. **longhorn** - Distributed block storage
   ...
```

## Files

- `namespace.yaml` - longhorn-system namespace
- `helmrepository.yaml` - Longhorn Helm repository reference
- `helmrelease.yaml` - Flux HelmRelease with Pi-optimized values
- `kustomization.yaml` - Flux kustomization
- `values.yaml` - Complete Helm values reference (documentation)
- `install.sh` - Pre-flight checks and helpers
- `verify.sh` - Health check and validation script
- `backup-setup.sh` - SanDisk Extreme SD drive setup automation
- `README.md` - This file

## References

- [Longhorn Documentation](https://longhorn.io/docs/)
- [Longhorn Helm Chart](https://github.com/longhorn/longhorn/tree/master/chart)
- [Flux HelmRelease Documentation](https://fluxcd.io/docs/components/helm/helmreleases/)

## Support

For issues or questions:

1. Check Longhorn UI for volume and node status
2. Review pod logs: `kubectl logs -n longhorn-system -l app=longhorn-manager`
3. Check Longhorn documentation
4. Review cluster events: `kubectl get events -n longhorn-system --sort-by='.lastTimestamp'`
