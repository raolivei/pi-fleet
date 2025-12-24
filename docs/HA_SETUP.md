# High Availability (HA) Setup for Eldertree Cluster

## Current Setup

- **node-0** (192.168.2.86): Control plane (k3s server with embedded etcd)
- **node-1** (192.168.2.85): Worker node (k3s agent)

**Status**: Single control plane - **NOT HA**

If node-0 goes down:

- ❌ Cluster API is unavailable
- ❌ No new pods can be scheduled
- ⚠️ Existing pods on node-1 may continue running but cannot be managed
- ❌ No automatic failover

## Converting to HA Mode

k3s supports HA with multiple control plane nodes. You can convert your cluster to HA by adding node-1 as a second control plane node.

### Requirements for HA

- **Minimum 3 control plane nodes** for etcd quorum (recommended)
- **Or 2 control plane nodes** (works but less resilient - if one goes down, cluster is still down)
- All control plane nodes need:
  - Same k3s token
  - Access to each other on port 6443
  - Embedded etcd (already enabled with `--cluster-init`)

### Option 1: Add node-1 as Second Control Plane (2-node HA)

**Note**: With only 2 control plane nodes, if one goes down, the cluster is still down (no quorum). This provides redundancy for maintenance but not true HA.

**Steps**:

1. **Get the k3s token from node-0**:

   ```bash
   ssh raolivei@node-0 "sudo cat /var/lib/rancher/k3s/server/node-token"
   ```

2. **Convert node-1 to control plane**:

   ```bash
   cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet/ansible

   # First, remove node-1 as worker (if it's already joined)
   ssh raolivei@node-1 "sudo /usr/local/bin/k3s-agent-uninstall.sh"

   # Install k3s server on node-1 (as additional control plane)
   ansible-playbook playbooks/install-k3s.yml \
     --limit node-1 \
     -e k3s_token=YOUR_TOKEN_FROM_STEP_1 \
     -e k3s_hostname=node-1 \
     -e k3s_additional_server=true
   ```

3. **Verify both control planes**:
   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   kubectl get nodes
   # Should show both node-0 and node-1 as control-plane
   ```

### Option 2: True HA with 3 Control Plane Nodes (Recommended)

For true HA, you need 3 control plane nodes. This requires adding a third Raspberry Pi.

**Steps**:

1. Add third node to inventory (`ansible/inventory/hosts.yml`)
2. Run `setup-all-nodes.yml` on the new node
3. Install k3s server on the new node with the same token
4. All 3 nodes will form an etcd quorum

### Creating Ansible Playbook for Additional Control Plane

To properly support adding additional control plane nodes, we should create a playbook that:

1. Checks if node is already a worker and removes it
2. Installs k3s server with `--server` flag (not `--cluster-init`)
3. Uses existing token from first control plane
4. Connects to existing cluster

**Example playbook structure**:

```yaml
- name: Install k3s additional control plane
  hosts: raspberry_pi
  become: true
  vars:
    k3s_token: "" # Required - from first control plane
    k3s_server_url: "https://node-0:6443" # First control plane
    k3s_hostname: "{{ inventory_hostname }}"

  tasks:
    - name: Remove k3s agent if exists
      shell: /usr/local/bin/k3s-agent-uninstall.sh
      when: k3s_agent_exists
      ignore_errors: true

    - name: Install k3s server (additional control plane)
      shell: |
        curl -sfL https://get.k3s.io | sh -s - server \
          --server {{ k3s_server_url }} \
          --token {{ k3s_token }} \
          --tls-san={{ k3s_hostname }}
```

## Current Limitations

With your current 2-node setup:

- ✅ Can run workloads on both nodes
- ✅ Can do maintenance on one node at a time
- ❌ No automatic failover if control plane goes down
- ❌ Cluster unavailable if control plane is down

## Recommendations

1. **For development/testing**: Current setup is fine
2. **For production**: Consider adding a third node for true HA
3. **For now**: Ensure good backups and monitoring of node-0

## Monitoring

To monitor cluster health:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check node status
kubectl get nodes

# Check control plane pods
kubectl get pods -n kube-system

# Check etcd health (if HA)
kubectl get pods -n kube-system | grep etcd
```

## Backup Strategy

Since you have a single control plane, ensure you have:

- ✅ Regular backups of etcd (k3s stores cluster state here)
- ✅ Backups of node-0 configuration
- ✅ Documentation of how to restore

See: [BACKUP_STRATEGY.md](BACKUP_STRATEGY.md)
