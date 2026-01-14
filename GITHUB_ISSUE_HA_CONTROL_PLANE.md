# GitHub Issue: Implement High Availability Control Plane

**Copy the content below and paste it into a new GitHub issue at:**
https://github.com/raolivei/pi-fleet/issues/new

---

## Title

Implement High Availability Control Plane for Eldertree Cluster

## Body (copy everything below this line)

## Overview

Implement high availability (HA) control plane for the eldertree Kubernetes cluster to ensure the cluster remains operational even when node-1 (current control plane) is shut down.

## Current Situation

### Cluster Architecture

- **node-1**: Control plane (192.168.2.101) - **Single point of failure**
- **node-2**: Worker node (192.168.2.102) - Currently NotReady
- **node-3**: Worker node (192.168.2.103) - Ready
- **Longhorn**: Configured with 2 replicas, hard anti-affinity

### Problem Statement

When node-1 (control plane) goes down:

- Kubernetes API server becomes unavailable
- etcd becomes unavailable
- Cannot manage cluster (scale, update, create resources)
- Services may continue running, but no management possible

### Understanding Longhorn's Role

**What Longhorn DOES:**

- Provides storage redundancy - data survives single node failure
- Replicates volumes across multiple nodes (2 replicas)
- Ensures data availability even if one node fails

**What Longhorn DOES NOT do:**

- Does not make the cluster API available if control plane is down
- Does not allow pod management without control plane
- Does not provide etcd redundancy (that's separate)

## Solution: HA Control Plane

Convert all 3 nodes to control plane nodes with embedded etcd HA.

**Architecture:**

```
Control Plane Nodes (HA):
- node-1: Control plane (existing)
- node-2: Control plane (convert from worker)
- node-3: Control plane (convert from worker)

All nodes can also run workloads (control plane + worker)
```

**Benefits:**

- Cluster remains operational if 1 control plane node fails
- etcd quorum maintained (3 nodes = can lose 1)
- API server available from any control plane node
- Full cluster management continues

## Implementation Plan

### Phase 1: Preparation

- [ ] Fix node-2 NotReady status using `scripts/fix-node-2-k3s.sh`
- [ ] Verify Longhorn is operational on all nodes
- [ ] Backup etcd data and document current cluster state

### Phase 2: HA Control Plane Setup

- [ ] Update Ansible playbooks to support HA control plane installation
  - `ansible/playbooks/install-k3s.yml`
  - `ansible/playbooks/configure-k3s-gigabit.yml`
- [ ] Convert node-2 from worker to control plane node
- [ ] Convert node-3 from worker to control plane node
- [ ] Verify 3-node etcd quorum
- [ ] Update kubeconfig to support multiple API endpoints

### Phase 3: Testing & Optimization

- [ ] Test HA by shutting down node-1, verify cluster remains operational
- [ ] Migrate all stateful applications from local-path to Longhorn
- [ ] Configure pod anti-affinity rules to spread replicas across nodes
- [ ] Create CLUSTER_HA_GUIDE.md documentation

## Files to Modify

- `ansible/playbooks/install-k3s.yml` - Add HA control plane support
- `ansible/playbooks/configure-k3s-gigabit.yml` - Update for HA mode
- `scripts/setup-kubeconfig-eldertree.sh` - Support multiple API endpoints
- `docs/CLUSTER_HA_GUIDE.md` - New guide for HA setup
- `docs/NODE_TROUBLESHOOTING.md` - Update with HA considerations

## Testing Plan

1. **HA Control Plane Test**

   - Shut down node-1
   - Verify API server accessible from node-2
   - Verify pods continue running
   - Verify Longhorn volumes accessible

2. **Storage Resilience Test**

   - Shut down node with Longhorn replica
   - Verify volume remains accessible
   - Verify replica rebuilds on another node

3. **Full Cluster Test**
   - Shut down node-1
   - Verify all services accessible
   - Verify can create new pods
   - Verify can update deployments

## Key Considerations

- Resource Usage: Control plane nodes need minimal resources. All 3 nodes can also run workloads.
- Network Requirements: All nodes must communicate on port 6443 (API server) and etcd ports.
- Quorum: With 3 control plane nodes, can lose 1 node and maintain quorum (minimum for HA).
- Kubeconfig: After HA setup, should point to load-balanced endpoint or all control plane nodes.

## Related Documentation

- [Longhorn Storage README](clusters/eldertree/storage/longhorn/README.md)
- [Node Troubleshooting Guide](docs/NODE_TROUBLESHOOTING.md)
- [K3s HA Documentation](https://docs.k3s.io/installation/ha)

## Acceptance Criteria

- [ ] All 3 nodes are control plane nodes with etcd HA
- [ ] Cluster remains operational when any single node is shut down
- [ ] API server accessible from any control plane node
- [ ] All stateful apps migrated to Longhorn
- [ ] Documentation updated with HA setup guide
- [ ] HA failover tested and verified
