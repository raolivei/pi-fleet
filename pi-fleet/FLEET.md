# Fleet Naming Convention

## Control Plane

- **eldertree** - Main control plane node (Raspberry Pi 5, 8GB)

## Worker Nodes

- **fleet-worker-01** - First worker node
- **fleet-worker-02** - Second worker node
- **fleet-worker-XX** - Additional workers as needed

## Network Configuration

Add to `/etc/hosts` on all machines:

```
<IP>  eldertree
<IP>  fleet-worker-01
<IP>  fleet-worker-02
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
