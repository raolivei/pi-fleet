# High Availability (HA) Setup for Eldertree Cluster

## Current Setup ✅

- **node-1** (10.0.0.1): Control plane + etcd
- **node-2** (10.0.0.2): Control plane + etcd
- **node-3** (10.0.0.3): Control plane + etcd

**Status**: **3-Node HA Control Plane** ✅

**Quorum**: Can lose 1 node and maintain quorum (2/3 = 66.7% > 50%)

If any single node goes down:

- ✅ Cluster API remains available
- ✅ New pods can still be scheduled
- ✅ Existing pods continue running
- ✅ Automatic failover to remaining control plane nodes

## Converting to HA Mode

k3s supports HA with multiple control plane nodes. The Eldertree cluster has been successfully converted to 3-node HA.

### Critical: Firewall Configuration

**⚠️ IMPORTANT**: When adding control plane nodes, you **MUST** configure firewall rules for etcd ports. Without these rules, etcd members cannot communicate and the cluster will fail to form quorum.

**Required Firewall Rules** (automated in Ansible playbooks):

```bash
# On all control plane nodes (etcd communication)
sudo ufw allow 2379/tcp comment 'etcd client'
sudo ufw allow 2380/tcp comment 'etcd peer'
sudo ufw allow from 10.0.0.0/8 to any port 2379 comment 'etcd client from cluster'
sudo ufw allow from 10.0.0.0/8 to any port 2380 comment 'etcd peer from cluster'

# On ALL nodes (k3s networking - CRITICAL for cross-node pod communication)
sudo ufw allow from 10.0.0.0/24 comment 'k3s internal network'
sudo ufw allow from 10.42.0.0/16 comment 'k3s pod network'
sudo ufw allow from 10.43.0.0/16 comment 'k3s service network'
sudo ufw allow 8472/udp comment 'k3s flannel VXLAN'
```

**Note**: Without the VXLAN and pod network rules, cross-node pod communication will fail, breaking DNS, services, and distributed storage (Longhorn).

**Automation**: The `install-k3s.yml` and `convert-worker-to-control-plane.yml` playbooks automatically configure these firewall rules when installing control plane nodes.

### Requirements for HA

- **Minimum 3 control plane nodes** for etcd quorum (recommended) ✅ **ACHIEVED**
- **Or 2 control plane nodes** (works but less resilient - if one goes down, cluster is still down)
- All control plane nodes need:
  - Same k3s token
  - Access to each other on port **6443** (API server)
  - Access to each other on port **2379** (etcd client)
  - Access to each other on port **2380** (etcd peer)
  - Embedded etcd (enabled with `--cluster-init` on first node, `--server` on additional nodes)
  - **Firewall rules** allowing etcd ports (2379, 2380) from cluster network (10.0.0.0/8)

### Option 1: Add node-1 as Second Control Plane (2-node HA)

**Note**: With only 2 control plane nodes, if one goes down, the cluster is still down (no quorum). This provides redundancy for maintenance but not true HA.

**Steps**:

1. **Get the k3s token from node-1**:

   ```bash
   ssh raolivei@node-1 "sudo cat /var/lib/rancher/k3s/server/node-token"
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
   # Should show both node-1 and node-1 as control-plane
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
    k3s_server_url: "https://node-1:6443" # First control plane
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

## Current Capabilities

With the 3-node HA setup:

- ✅ Can run workloads on all nodes
- ✅ Can do maintenance on one node at a time (cluster remains operational)
- ✅ Automatic failover if one control plane goes down
- ✅ Cluster remains available if one node is down
- ✅ True HA with etcd quorum (can lose 1 of 3 nodes)

## Troubleshooting

### etcd Member Stuck as Learner

If a node's etcd member is stuck as a learner and cannot sync:

1. **Check firewall rules**: Ensure ports 2379 and 2380 are open

   ```bash
   sudo ufw status | grep -E '(2379|2380)'
   ```

2. **Check network connectivity**: Test from other nodes

   ```bash
   # From node-1, test connection to node-3
   openssl s_client -connect 10.0.0.3:2380 -servername node-3.eldertree.local
   ```

3. **Check etcd member status**:

   ```bash
   # On any control plane node
   sudo /usr/local/bin/etcdctl --endpoints=https://127.0.0.1:2379 \
     --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
     --cert=/var/lib/rancher/k3s/server/tls/etcd/client.crt \
     --key=/var/lib/rancher/k3s/server/tls/etcd/client.key \
     member list -w table
   ```

4. **Common issues**:
   - Firewall blocking connections (most common)
   - Network interface misconfiguration
   - TLS certificate mismatches
   - etcd data directory corruption

## Recommendations

1. ✅ **HA achieved**: 3-node control plane provides true high availability
2. ✅ **Firewall automation**: Ansible playbooks handle firewall rules automatically
3. ✅ **Monitoring**: Monitor etcd member health regularly
4. ✅ **Backups**: Continue regular etcd backups (now with redundancy)

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
- ✅ Backups of node-1 configuration
- ✅ Documentation of how to restore

See: [BACKUP_STRATEGY.md](BACKUP_STRATEGY.md)
