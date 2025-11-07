# Fleet Naming Convention

## Control Plane

- **eldertree** - Main control plane node (Raspberry Pi 5, 8GB)
  - IP: `192.168.2.83`
  - Single-node cluster

## Worker Nodes

- **fleet-worker-01** - First worker node (future)
- **fleet-worker-02** - Second worker node (future)
- **fleet-worker-XX** - Additional workers as needed

## Network Configuration

See [NETWORK.md](NETWORK.md) for full network setup guide.

Add to `/etc/hosts` on all machines:

```
192.168.2.83  eldertree
192.168.2.83  longhorn.eldertree.local
192.168.2.83  grafana.eldertree.local
192.168.2.83  prometheus.eldertree.local
```

## Joining Workers

```bash
# Get token from control plane
cat terraform/k3s-node-token

# On each worker node
curl -sfL https://get.k3s.io | \
  K3S_URL=https://eldertree:6443 \
  K3S_TOKEN=<token> \
  sh -
```
