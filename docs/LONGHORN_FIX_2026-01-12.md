# Longhorn Fix - January 12, 2026

## Summary

Longhorn has been successfully fixed and is now operational with **distributed storage replication across all 3 nodes**.

## Root Causes Found and Fixed

### 1. Firewall Rules Missing (Primary Issue)

The Flannel VXLAN overlay network was being blocked by UFW firewall on the Raspberry Pi nodes. This prevented cross-node pod communication, which broke:
- DNS resolution (CoreDNS on one node couldn't be reached from pods on other nodes)
- Longhorn webhook connectivity
- General pod-to-pod communication across nodes

**Fix Applied:**
```bash
# On all nodes (192.168.2.101, 192.168.2.102, 192.168.2.103):
sudo ufw allow from 10.0.0.0/24 comment 'k3s internal network'
sudo ufw allow from 10.42.0.0/16 comment 'k3s pod network'
sudo ufw allow from 10.43.0.0/16 comment 'k3s service network'
sudo ufw allow 8472/udp comment 'k3s flannel VXLAN'
```

### 2. Missing CRDs from Helm Install

The Helm chart installation was missing two critical CRDs:
- `engineimages.longhorn.io`
- `nodes.longhorn.io`

**Fix Applied:**
```bash
# Applied full Longhorn manifest to create missing CRDs
curl -sL https://raw.githubusercontent.com/longhorn/longhorn/v1.7.2/deploy/longhorn.yaml | kubectl apply -f -
```

### 3. kubelet-root-dir Configuration

The CSI driver deployer needed the correct kubelet root directory for k3s.

**Fix Applied:**
```bash
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --version 1.7.2 \
  --set csi.kubeletRootDir="/var/lib/kubelet" \
  --set defaultSettings.defaultDataPath="/var/lib/longhorn" \
  --set persistence.defaultClassReplicaCount=2
```

## Current Status

### Longhorn Components (21 pods running)
- ✅ 3 longhorn-manager pods (one per node)
- ✅ 3 engine-image pods (one per node)
- ✅ 3 instance-manager pods (one per node)
- ✅ 3 longhorn-csi-plugin pods (one per node)
- ✅ 2 longhorn-ui pods
- ✅ 1 longhorn-driver-deployer pod
- ✅ 3 csi-attacher pods
- ✅ 3 csi-provisioner pods
- ✅ 3 csi-resizer pods
- ✅ 3 csi-snapshotter pods

### Longhorn Nodes
| Node | Ready | Schedulable |
|------|-------|-------------|
| node-1.eldertree.local | ✅ True | ✅ True |
| node-2.eldertree.local | ✅ True | ✅ True |
| node-3.eldertree.local | ✅ True | ✅ True |

### Storage Configuration
- **Replicas per volume**: 3 (configurable)
- **Storage class**: `longhorn` (default)
- **Data path**: `/var/lib/longhorn`

## HA Capabilities

With Longhorn operational:

1. **Data survives node failure**: With 3 replicas across 3 nodes, data remains available if any 1 node fails
2. **Automatic replica rebuilding**: When a node comes back online, replicas are automatically rebuilt
3. **Pod rescheduling**: Pods using Longhorn volumes can be rescheduled to healthy nodes

## Testing

```bash
# Create a test PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-test
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 100Mi
EOF

# Check volume and replicas
kubectl get pvc longhorn-test
kubectl get volumes.longhorn.io -n longhorn-system
kubectl get replicas.longhorn.io -n longhorn-system

# Clean up
kubectl delete pvc longhorn-test
```

## Lessons Learned

1. **Always configure firewall rules for k3s networking**: The CNI needs specific ports open (8472/udp for VXLAN)
2. **Helm CRD installation can fail silently**: Always verify CRDs exist after installation
3. **Cross-node networking issues manifest as service connectivity problems**: If DNS or services time out, check firewall first

## Related Documentation

- [HA_SETUP.md](./HA_SETUP.md) - High Availability control plane setup
- [NETWORK_CONFIGURATION_BEST_PRACTICES.md](./NETWORK_CONFIGURATION_BEST_PRACTICES.md) - Network configuration guidelines
- [PREVENT_NETWORK_ISSUES.md](./PREVENT_NETWORK_ISSUES.md) - Preventing network configuration issues


