#!/bin/bash
# Diagnose node-0 and node-1 NotReady issues
# Identifies IP conflicts, network issues, and configuration problems

set -e

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
SSH_KEY="$HOME/.ssh/id_ed25519_raolivei"

echo "=========================================="
echo "Diagnosing Node Issues - eldertree Cluster"
echo "=========================================="
echo ""

export KUBECONFIG="$KUBECONFIG"

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG" ]; then
    echo "❌ Kubeconfig not found: $KUBECONFIG"
    exit 1
fi

echo "1. Current Node Status:"
echo "----------------------"
kubectl get nodes -o wide
echo ""

echo "2. Node Conditions:"
echo "------------------"
for node in node-0.eldertree.local node-1.eldertree.local; do
    echo ""
    echo "=== $node ==="
    kubectl describe node "$node" 2>&1 | grep -A 10 "Conditions:" || echo "  Cannot describe node"
done
echo ""

echo "3. IP Address Conflicts:"
echo "-------------------------"
echo "Checking for duplicate IPs..."
kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name): \(.status.addresses[] | select(.type=="InternalIP") | .address)"' | sort -k2
echo ""

echo "4. Network Connectivity Tests:"
echo "-------------------------------"
for ip in 192.168.2.100 192.168.2.101; do
    if ping -c 2 -W 2 "$ip" > /dev/null 2>&1; then
        echo "  ✅ $ip: Reachable"
    else
        echo "  ❌ $ip: Unreachable"
    fi
done
echo ""

echo "5. SSH Connectivity:"
echo "--------------------"
if [ -f "$SSH_KEY" ]; then
    for ip in 192.168.2.100 192.168.2.101; do
        if ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "raolivei@$ip" "hostname" > /dev/null 2>&1; then
            echo "  ✅ $ip: SSH accessible"
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@$ip" "hostname && ip addr show eth0 | grep 'inet ' && systemctl is-active k3s" 2>/dev/null || echo "    (Could not get details)"
        else
            echo "  ❌ $ip: SSH not accessible"
        fi
    done
else
    echo "  ⚠️  SSH key not found: $SSH_KEY"
fi
echo ""

echo "6. Pods on Problem Nodes:"
echo "-------------------------"
echo "Pods on node-0:"
kubectl get pods -A -o wide --field-selector spec.nodeName=node-0.eldertree.local 2>&1 | head -10 || echo "  No pods or node not found"
echo ""
echo "Pods on node-1:"
kubectl get pods -A -o wide --field-selector spec.nodeName=node-1.eldertree.local 2>&1 | head -10 || echo "  No pods or node not found"
echo ""

echo "7. etcd Status (if accessible):"
echo "-------------------------------"
if ssh -i "$SSH_KEY" -o ConnectTimeout=5 "raolivei@192.168.2.101" "sudo k3s etcd-snapshot list" > /dev/null 2>&1; then
    echo "  ✅ Can access etcd on node-1"
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "raolivei@192.168.2.101" "sudo k3s kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels[\"node-role.kubernetes.io/control-plane\"]==\"true\") | \"\(.metadata.name): etcd-voter=\(.status.conditions[] | select(.type==\"EtcdIsVoter\") | .status)\"'" 2>/dev/null || echo "  Could not get etcd status"
else
    echo "  ⚠️  Cannot access etcd"
fi
echo ""

echo "8. Recommendations:"
echo "-------------------"
echo ""
echo "Issues Found:"
echo ""

# Check for IP conflicts
IP_CONFLICTS=$(kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name):\(.status.addresses[] | select(.type=="InternalIP") | .address)"' | sort -t: -k2 | uniq -d -f1)
if [ -n "$IP_CONFLICTS" ]; then
    echo "  ❌ IP CONFLICT DETECTED:"
    echo "$IP_CONFLICTS" | while IFS=: read -r node ip; do
        echo "    - $node has IP $ip (conflict!)"
    done
    echo ""
    echo "  Fix: Ensure each node has a unique IP address"
fi

# Check for unreachable nodes
if ! ping -c 1 -W 2 192.168.2.100 > /dev/null 2>&1; then
    echo "  ❌ node-0 (192.168.2.100) is unreachable"
    echo ""
    echo "  Possible causes:"
    echo "    - Node is powered off"
    echo "    - Network cable disconnected"
    echo "    - IP address changed"
    echo "    - Firewall blocking"
    echo ""
    echo "  Fix options:"
    echo "    1. Power on node-0 and check network"
    echo "    2. Remove node-0 from cluster if no longer in use:"
    echo "       kubectl delete node node-0.eldertree.local"
fi

# Check for NotReady nodes
NOT_READY=$(kubectl get nodes -o json | jq -r '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status!="True")) | .metadata.name')
if [ -n "$NOT_READY" ]; then
    echo "  ⚠️  NotReady nodes:"
    echo "$NOT_READY" | while read -r node; do
        echo "    - $node"
    done
fi

echo ""
echo "=========================================="
echo "Diagnosis Complete"
echo "=========================================="




