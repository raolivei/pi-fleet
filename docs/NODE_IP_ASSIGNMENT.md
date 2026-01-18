# Node IP Assignment

## IP Address Pattern

The eldertree cluster uses a consistent IP assignment pattern for all nodes:

- **node-1**: `192.168.2.80`
- **node-1**: `192.168.2.81`
- **node-2**: `192.168.2.82` (future)
- **node-3**: `192.168.2.83` (future)
- **node-N**: `192.168.2.8N` (where N is the node number)

## Formula

```
IP = 192.168.2.80 + node_number
```

Example:
- node-1 → 192.168.2.80 (80 + 0)
- node-1 → 192.168.2.81 (80 + 1)
- node-5 → 192.168.2.85 (80 + 5)

## Configuration

### Ansible Playbooks

When running playbooks, static IPs are automatically assigned based on the node number:

```bash
# Rebuild cluster (auto-assigns IPs)
ansible-playbook playbooks/rebuild-cluster.yml

# Manual override if needed
ansible-playbook playbooks/setup-system.yml \
  -e static_ip_override=192.168.2.80 \
  --limit node-1
```

### Inventory File

The inventory (`ansible/inventory/hosts.yml`) uses IP addresses for initial connection:

```yaml
node-1:
  ansible_host: 192.168.2.80  # Static IP
node-1:
  ansible_host: 192.168.2.81  # Static IP
```

### Netplan Configuration

Static IPs are configured via Netplan on each node:

```yaml
# /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.2.80/24  # node-1
      gateway4: 192.168.2.1
      nameservers:
        addresses: [192.168.2.1, 8.8.8.8]
```

## Hostname Pattern

**CRITICAL**: Hostnames MUST use FQDN format:

- ✅ `node-1.eldertree.local` (correct)
- ✅ `node-1.eldertree.local` (correct)
- ❌ `eldertree` (WRONG - causes cluster conflicts)
- ❌ `node-1` (WRONG - not FQDN)

The playbooks enforce this with validation checks to prevent accidental misconfiguration.

## Adding New Nodes

When adding a new node (e.g., node-2):

1. **Update inventory** (`ansible/inventory/hosts.yml`):
   ```yaml
   node-2:
     ansible_host: 192.168.2.82
     ansible_user: raolivei
     ansible_ssh_private_key_file: ~/.ssh/id_ed25519_raolivei
     ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
     ansible_python_interpreter: /usr/bin/python3
     poe_hat_enabled: true
   ```

2. **Run setup** - IP will be auto-assigned:
   ```bash
   ansible-playbook playbooks/rebuild-cluster.yml --limit node-2
   ```

3. **Verify IP assignment**:
   ```bash
   ansible node-2 -m shell -a "ip addr show eth0 | grep 'inet '"
   ```

## DHCP Fallback

If you need to use DHCP instead of static IPs:

```bash
ansible-playbook playbooks/setup-system.yml \
  -e static_ip_override="" \
  --limit node-1
```

**Note**: DHCP is not recommended for production as IPs may change, breaking k3s cluster connectivity.

## Troubleshooting

### Node Lost Network Connectivity

If a node becomes unreachable after IP configuration:

1. **Physical access**: Connect keyboard/monitor
2. **Check Netplan config**: `cat /etc/netplan/01-netcfg.yaml`
3. **Fix IP**: Edit to correct IP (192.168.2.8X)
4. **Apply**: `sudo netplan apply`
5. **Verify**: `ip addr show eth0`

### IP Conflict

If two nodes have the same IP:

1. Check current IPs: `ansible all -m shell -a "ip addr show eth0 | grep 'inet '"`
2. Fix conflicting node's Netplan config
3. Apply changes: `sudo netplan apply`

## Related Documentation

- [Network Architecture](./NETWORK_ARCHITECTURE.md) - Complete network architecture overview
- [Cluster Setup Guide](../ansible/README.md)
- [Network Configuration](./IP_BASED_NETWORKING.md)
- [Node Configuration Summary](./NODE_CONFIGURATION_SUMMARY.md)

