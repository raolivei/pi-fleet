#!/bin/bash
# Validate network configuration on all nodes to prevent dual IP issues
# This script checks for common network misconfigurations that cause instability

set -e

SSH_KEY="$HOME/.ssh/id_ed25519_raolivei"
NODES=(
    "192.168.2.101:node-1.eldertree.local:192.168.2.101"
    "192.168.2.102:node-2.eldertree.local:192.168.2.102"
    "192.168.2.103:node-3.eldertree.local:192.168.2.103"
)

# VIP that kube-vip uses (should be present on leader node)
VIP="192.168.2.100"

ERRORS=0
WARNINGS=0

echo "=========================================="
echo "Network Configuration Validation"
echo "=========================================="
echo ""

for node_info in "${NODES[@]}"; do
    IFS=':' read -r node_ip node_hostname expected_ip <<< "$node_info"
    echo "=== $node_hostname ($node_ip) ==="
    
    # Run validation checks on remote node
    ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "raolivei@$node_ip" bash << ENDSSH
set -e

VIP="$VIP"
EXPECTED_IP="$expected_ip"

# 1. Check for multiple IPs on wlan0 (excluding VIP)
echo "1. Checking wlan0 IPs..."
WLAN0_IPS=\$(ip addr show wlan0 | grep "inet " | grep -v "\$VIP" | wc -l)
if [ "\$WLAN0_IPS" -gt 1 ]; then
    echo "   ❌ ERROR: Multiple IPs detected on wlan0 (excluding VIP)!"
    ip addr show wlan0 | grep "inet " | grep -v "\$VIP"
    exit 1
elif [ "\$WLAN0_IPS" -eq 0 ]; then
    echo "   ❌ ERROR: No IP found on wlan0!"
    exit 1
else
    CURRENT_IP=\$(ip addr show wlan0 | grep "inet " | grep -v "\$VIP" | awk '{print \$2}' | cut -d'/' -f1)
    if [ "\$CURRENT_IP" = "\$EXPECTED_IP" ]; then
        echo "   ✅ Correct IP: \$CURRENT_IP"
    else
        echo "   ⚠️  WARNING: Expected \$EXPECTED_IP but found \$CURRENT_IP"
    fi
fi

# 2. Check for DHCP enabled in netplan
echo ""
echo "2. Checking netplan DHCP configuration..."
NETPLAN_FILES=\$(sudo ls /etc/netplan/*.yaml 2>/dev/null || echo "")
if [ -z "\$NETPLAN_FILES" ]; then
    echo "   ⚠️  WARNING: No netplan files found"
else
    DHCP_FOUND=false
    for file in /etc/netplan/*.yaml; do
        if [ -f "\$file" ] && sudo grep -q "dhcp4: true" "\$file" 2>/dev/null; then
            echo "   ❌ ERROR: DHCP enabled in \$file"
            sudo grep "dhcp4:" "\$file"
            DHCP_FOUND=true
            exit 1
        fi
    done
    if [ "\$DHCP_FOUND" = false ]; then
        echo "   ✅ DHCP disabled in all netplan files"
    fi
fi

# 3. Check NetworkManager configuration
echo ""
echo "3. Checking NetworkManager configuration..."
if command -v nmcli > /dev/null 2>&1; then
    WLAN0_CONN=\$(sudo nmcli -t -f NAME,DEVICE connection show | grep ":wlan0" | cut -d':' -f1 | head -1)
    if [ -n "\$WLAN0_CONN" ]; then
        IPV4_METHOD=\$(sudo nmcli -t connection show "\$WLAN0_CONN" | grep "ipv4.method:" | cut -d':' -f2)
        IPV4_ADDRESSES=\$(sudo nmcli -t connection show "\$WLAN0_CONN" | grep "ipv4.addresses:" | cut -d':' -f2)
        if [ "\$IPV4_METHOD" = "auto" ] || [ "\$IPV4_METHOD" = "dhcp" ]; then
            if [ -n "\$IPV4_ADDRESSES" ]; then
                echo "   ⚠️  WARNING: NetworkManager has both DHCP and static IP configured"
                echo "   Connection: \$WLAN0_CONN"
                echo "   Method: \$IPV4_METHOD"
                echo "   Addresses: \$IPV4_ADDRESSES"
            else
                echo "   ✅ NetworkManager configured correctly"
            fi
        else
            echo "   ✅ NetworkManager using manual/static configuration"
        fi
    else
        echo "   ⚠️  WARNING: No NetworkManager connection found for wlan0"
    fi
else
    echo "   ⚠️  WARNING: NetworkManager (nmcli) not available"
fi

# 4. Check routing table for duplicate routes
echo ""
echo "4. Checking routing table..."
DUPLICATE_ROUTES=\$(ip route show | grep "192.168.2.0/24" | grep "wlan0" | wc -l)
if [ "\$DUPLICATE_ROUTES" -gt 1 ]; then
    echo "   ⚠️  WARNING: Multiple routes for 192.168.2.0/24 on wlan0"
    ip route show | grep "192.168.2.0/24" | grep "wlan0"
else
    echo "   ✅ No duplicate routes found"
fi

# 5. Check interface status
echo ""
echo "5. Checking interface status..."
if ip link show wlan0 | grep -q "state UP"; then
    echo "   ✅ wlan0 is UP"
else
    echo "   ❌ ERROR: wlan0 is DOWN!"
    exit 1
fi

exit 0
ENDSSH

    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        ERRORS=$((ERRORS + 1))
    fi
    
    echo ""
done

echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo "Total Errors: $ERRORS"
echo "Total Warnings: $WARNINGS"
echo ""

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo "✅ All nodes have correct network configuration!"
    exit 0
elif [ "$ERRORS" -eq 0 ]; then
    echo "⚠️  Some warnings found, but no critical errors"
    exit 0
else
    echo "❌ Errors found! Please fix network configuration issues"
    echo ""
    echo "To fix issues, run:"
    echo "  ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/fix-network-config.yml"
    exit 1
fi
