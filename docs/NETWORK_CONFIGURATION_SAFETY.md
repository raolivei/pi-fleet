# Network Configuration Safety

## ⚠️ CRITICAL: DHCP is Default (DO NOT DISABLE)

**The playbook now preserves DHCP by default** to prevent network breakage.

## Problem

Previously, the `setup-system.yml` playbook would automatically configure static IP when `node_ip` was provided, which could:
- Break network connectivity if configuration was incorrect
- Disable DHCP without explicit user consent
- Require physical access to recover

## Solution

**Static IP configuration is now OPT-IN only**. You must explicitly enable it.

### Default Behavior (DHCP - Safe)

```bash
# This will NOT configure static IP - network stays on DHCP
ansible-playbook -i inventory/hosts.yml playbooks/setup-system.yml \
  --limit node-0 \
  -e "node_hostname=node-0" \
  -e "node_ip=192.168.2.86"
```

Even if you provide `node_ip`, the playbook will:
- ✅ Set hostname
- ✅ Configure user, packages, SSH
- ✅ **Keep DHCP enabled** (network unchanged)

### To Configure Static IP (Explicit)

You must pass **both** flags:

```bash
# This WILL configure static IP
ansible-playbook -i inventory/hosts.yml playbooks/setup-system.yml \
  --limit node-0 \
  -e "node_hostname=node-0" \
  -e "configure_static_ip=true" \
  -e "static_ip=192.168.2.86"
```

**Required flags:**
- `configure_static_ip=true` - Explicitly enable static IP
- `static_ip=192.168.2.86` - The IP address to use

## Why This Change?

1. **Safety**: DHCP is safer - router manages IPs
2. **Flexibility**: Can change IPs without breaking network
3. **Recovery**: Easier to recover if something goes wrong
4. **Explicit**: User must intentionally choose static IP

## Recommended Approach

**For most setups, use DHCP with router reservations:**

1. Configure router DHCP reservations (assigns static IP via DHCP)
2. Run playbook without `configure_static_ip=true`
3. Network stays on DHCP (safer)
4. Router assigns consistent IP (best of both worlds)

## Recovery

If network breaks:

```bash
# On the Pi (physical access):
sudo rm /etc/netplan/*.yaml
sudo netplan apply
# Network will revert to DHCP
```

## Playbook Variables

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `configure_static_ip` | `false` | No | Must be `true` to enable static IP |
| `static_ip` | `""` | No | IP address (only used if `configure_static_ip=true`) |
| `node_ip` | `""` | No | Legacy alias for `static_ip` (doesn't enable static IP) |

## Examples

### Safe Setup (DHCP)
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-system.yml \
  --limit node-0 \
  -e "node_hostname=node-0"
```

### Static IP Setup (Explicit)
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-system.yml \
  --limit node-0 \
  -e "node_hostname=node-0" \
  -e "configure_static_ip=true" \
  -e "static_ip=192.168.2.86"
```

## Related Documentation

- [GIGABIT_NETWORK_SETUP.md](./GIGABIT_NETWORK_SETUP.md) - Gigabit network configuration
- [FRESH_INSTALL_NODE0.md](./FRESH_INSTALL_NODE0.md) - Fresh install guide

