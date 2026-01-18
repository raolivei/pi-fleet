# Setup Node-1 (Complete Process)

This document captures the complete process used to set up node-1, which serves as the reference pattern for adding new nodes to the eldertree cluster.

## Process Summary

The setup process for node-1 established the standard pattern for all nodes:

1. **NVMe Boot Configuration**: Fixed `cmdline.txt` to boot from NVMe root partition
2. **System Configuration**: Set hostname and management IP via `setup-system.yml`
3. **Network Configuration**: Configured eth0 with gigabit IP only (matching node-1 pattern)
4. **k3s Worker Setup**: Installed and configured k3s-agent
5. **Gigabit Network**: Configured k3s to use gigabit IP and interface

## Key Pattern Established

- **Management IP**: On `wlan0` via NetworkManager/DHCP
- **Gigabit IP**: On `eth0` only via netplan (`10-eth0-gigabit.yaml`)
- **Boot**: From NVMe (SD card removed after setup)
- **Hostname**: `node-X.eldertree.local`

## Complete Documentation

For the full process, see: [ADD_NODE_COMPLETE.md](ADD_NODE_COMPLETE.md)

This document provides step-by-step instructions for adding any new node to the cluster, following the pattern established with node-1.
