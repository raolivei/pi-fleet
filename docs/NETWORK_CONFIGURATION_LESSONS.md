# Network Configuration Lessons Learned

## Critical: NetworkManager Configuration Persistence

### The Problem

When configuring eth0 via NetworkManager using `nmcli`, the configuration may not persist across reboots if:

1. **NetworkManager keyfile plugin reads netplan files**: On Debian/Raspberry Pi OS, NetworkManager uses the keyfile plugin which reads netplan YAML files. If any netplan file references eth0 (even indirectly), it can override NetworkManager connections created via `nmcli`.

2. **Connection not properly saved**: The `nmcli` command may create a connection that works immediately but isn't properly persisted to `/etc/NetworkManager/system-connections/`.

3. **Missing verification**: Without verifying persistence after reboot, configurations may appear to work but fail on next boot.

### The Failure Pattern

**What happened with node-1**:
1. Created NetworkManager connection via `nmcli` while node was running
2. Connection worked immediately (`ip addr show eth0` showed correct IP)
3. After reboot, configuration was lost
4. Hostname also reverted (separate issue)

### Correct Approach: Always Verify Persistence

When configuring network interfaces, **ALWAYS**:

1. **Check NetworkManager configuration**:
   ```bash
   # Verify connection file exists
   sudo ls -la /etc/NetworkManager/system-connections/eth0*
   
   # Check NetworkManager config
   sudo cat /etc/NetworkManager/NetworkManager.conf | grep -i keyfile
   
   # Verify connection details
   sudo nmcli connection show eth0
   ```

2. **Check for netplan conflicts**:
   ```bash
   # List all netplan files
   sudo ls -la /etc/netplan/
   
   # Check if any reference eth0
   sudo grep -r "eth0" /etc/netplan/
   ```

3. **Verify persistence**:
   ```bash
   # After configuration, reboot and verify
   sudo reboot
   # After reboot, check:
   ip addr show eth0 | grep "inet "
   sudo nmcli connection show eth0
   ```

4. **Match working configuration exactly**:
   - If node-0 works, check its exact configuration:
     ```bash
     # On node-0
     sudo ls -la /etc/NetworkManager/system-connections/eth0*
     sudo cat /etc/NetworkManager/system-connections/eth0
     sudo cat /etc/NetworkManager/NetworkManager.conf
     sudo ls -la /etc/netplan/
     ```
   - Replicate the exact same approach on new nodes

### NetworkManager vs Netplan

**Key Understanding**:
- NetworkManager can read netplan files via the keyfile plugin
- If netplan files exist, they may take precedence over NetworkManager connections
- Both can coexist, but conflicts can cause unpredictable behavior
- **Best practice**: Use one method consistently per interface

**Current Pattern (node-0, node-1)**:
- **wlan0**: Managed by NetworkManager via netplan file (`90-NM-*.yaml`)
- **eth0**: Managed by NetworkManager via `nmcli` connection (no netplan file)

### Verification Checklist

Before declaring network configuration complete:

- [ ] Connection file exists in `/etc/NetworkManager/system-connections/`
- [ ] No conflicting netplan files for the interface
- [ ] NetworkManager config checked for keyfile plugin behavior
- [ ] Connection verified with `nmcli connection show`
- [ ] IP address verified with `ip addr show`
- [ ] **REBOOT TEST**: Configuration persists after reboot
- [ ] Hostname persists after reboot (separate but related issue)

### Related Issues

**Hostname Persistence**:
- Hostname may also revert if not properly configured
- Use `hostnamectl set-hostname` and update `/etc/hostname` and `/etc/hosts`
- Verify with `hostname` command after reboot

### Documentation Updates Needed

When documenting network configuration:
1. Include verification steps
2. Include reboot test requirement
3. Include troubleshooting for persistence issues
4. Reference this document for common pitfalls

