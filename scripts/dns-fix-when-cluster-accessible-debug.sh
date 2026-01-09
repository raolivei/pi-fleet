#!/bin/bash
# Script to complete DNS fixes when cluster is accessible (debug version - doesn't exit on error)
# Run this after cluster API becomes reachable

echo "=== Fixing DNS to work automatically without /etc/hosts ==="
echo ""

# Set kubeconfig
export KUBECONFIG=~/.kube/config-eldertree

echo "1. Verifying MetalLB configuration..."
kubectl get l2advertisement -n metallb-system default -o yaml | grep -A 3 "interfaces:" || echo "WARNING: interfaces not found in L2Advertisement or kubectl failed"

echo ""
echo "2. Applying MetalLB configuration..."
kubectl apply -f clusters/eldertree/core-infrastructure/metallb/config.yaml || echo "ERROR: Failed to apply MetalLB config"

echo ""
echo "3. Restarting MetalLB speakers..."
kubectl rollout restart daemonset -n metallb-system metallb-speaker || echo "ERROR: Failed to restart MetalLB speakers"

echo ""
echo "4. Waiting for MetalLB speakers to restart..."
sleep 15

echo ""
echo "5. Checking MetalLB logs for IP advertisement..."
kubectl logs -n metallb-system -l app.kubernetes.io/component=speaker --tail=50 2>&1 | grep -i "192.168.2.201\|wlan0\|announce" | tail -10 || echo "WARNING: Could not get MetalLB logs or no matches found"

echo ""
echo "6. Reconciling ExternalDNS HelmRelease..."
flux reconcile helmrelease -n external-dns external-dns || echo "ERROR: Failed to reconcile ExternalDNS"

echo ""
echo "7. Waiting for ExternalDNS to start..."
sleep 10

echo ""
echo "8. Checking ExternalDNS pod status..."
kubectl get pods -n external-dns || echo "ERROR: Failed to get ExternalDNS pods"

echo ""
echo "9. Checking ExternalDNS logs..."
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=20 2>&1 | grep -i "error\|success\|connected" || kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=20 2>&1 || echo "ERROR: Could not get ExternalDNS logs"

echo ""
echo "10. Testing LoadBalancer IP reachability..."
ping -c 2 192.168.2.201 || echo "WARNING: 192.168.2.201 not reachable yet"

echo ""
echo "11. Testing DNS resolution..."
dig @192.168.2.201 grafana.eldertree.local +short || echo "WARNING: DNS query failed"

echo ""
echo "=== DNS fix script completed ==="
echo "Next steps:"
echo "  - Test: nslookup grafana.eldertree.local"
echo "  - Test: curl http://grafana.eldertree.local/login"
echo "  - Verify no /etc/hosts entries needed"



