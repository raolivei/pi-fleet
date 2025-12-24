# Recovering Network Connectivity After Netplan Configuration

If nodes become unreachable after running Ansible playbooks that configure static IPs, follow these recovery steps.

## Symptoms

- Nodes become unreachable via SSH
- Ping fails to node IPs
- Ansible playbooks fail with "Connection timeout" or "Operation timed out"

## Root Cause

The playbook applied Netplan configuration with incorrect or conflicting static IP addresses, causing network connectivity loss.

## Recovery Steps

### Option 1: Physical Access (Recommended)

1. **Connect keyboard/monitor** to the affected node

2. **Check current Netplan configuration**:
   ```bash
   cat /etc/netplan/01-netcfg.yaml
   ```

3. **Fix the configuration**:
   ```bash
   sudo nano /etc/netplan/01-netcfg.yaml
   ```

4. **Set correct IP** based on node number:
   - **node-0**: `192.168.2.80`
   - **node-1**: `192.168.2.81`
   - **node-2**: `192.168.2.82` (future)

   Example for node-0:
   ```yaml
   network:
     version: 2
     renderer: networkd
     ethernets:
       eth0:
         dhcp4: no
         addresses:
           - 192.168.2.80/24
         gateway4: 192.168.2.1
         nameservers:
           addresses: [192.168.2.1, 8.8.8.8]
   ```

5. **Apply configuration**:
   ```bash
   sudo netplan apply
   ```

6. **Verify connectivity**:
   ```bash
   ip addr show eth0 | grep 'inet '
   ping -c 2 192.168.2.1
   ```

### Option 2: Use DHCP (Temporary)

If you need to recover quickly and can find the node via DHCP:

1. **Edit Netplan config**:
   ```bash
   sudo nano /etc/netplan/01-netcfg.yaml
   ```

2. **Change to DHCP**:
   ```yaml
   network:
     version: 2
     renderer: networkd
     ethernets:
       eth0:
         dhcp4: yes
   ```

3. **Apply**:
   ```bash
   sudo netplan apply
   ```

4. **Find new IP** from router DHCP leases

5. **Reconnect and fix static IP** using Option 1

### Option 3: Check Router DHCP Leases

If DHCP is still enabled, check your router's DHCP lease table to find the node's current IP address, then SSH in and fix the Netplan configuration.

## Prevention

The playbooks have been updated to:

1. **Validate hostname format** - Prevents setting hostname to just "eldertree"
2. **Auto-calculate static IPs** - Uses pattern: `192.168.2.80 + node_number`
3. **Require explicit override** - Static IPs only applied when explicitly configured

## Verification After Recovery

Once nodes are reachable again:

```bash
# Test connectivity
ansible raspberry_pi -m ping

# Verify hostnames
ansible raspberry_pi -m shell -a "hostname"

# Verify IPs
ansible raspberry_pi -m shell -a "ip addr show eth0 | grep 'inet '"

# Expected output:
# node-0: inet 192.168.2.80/24
# node-1: inet 192.168.2.81/24
```

## Related Documentation

- [Node IP Assignment](./NODE_IP_ASSIGNMENT.md)
- [Ansible README](../ansible/README.md)

