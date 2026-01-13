#!/bin/bash
set -e

echo "=== Pi-hole Status Check ==="
echo ""

# Use eldertree kubeconfig
export KUBECONFIG=~/.kube/config-eldertree

echo "1. Pi-hole Pod Status:"
kubectl get pods -n pihole -o wide
echo ""

echo "2. Pi-hole Service:"
kubectl get svc -n pihole pi-hole
echo ""

echo "3. MetalLB Status:"
kubectl get pods -n metallb-system
echo ""

echo "4. MetalLB IPAddressPool:"
kubectl get ipaddresspool -n metallb-system -o yaml | grep -A 3 "addresses:"
echo ""

echo "5. MetalLB L2Advertisement:"
kubectl get l2advertisement -n metallb-system default -o yaml | grep -A 5 "interfaces:"
echo ""

echo "6. MetalLB Speaker Logs (recent announcements):"
kubectl logs -n metallb-system -l app.kubernetes.io/component=speaker --tail=20 2>&1 | grep -i "announcing\|192.168.2.201" | tail -5
echo ""

echo "7. ExternalDNS Status:"
kubectl get pods -n external-dns
echo ""

echo "8. ExternalDNS Recent Logs:"
kubectl logs -n external-dns external-dns-7c4775466c-kghr8 --tail=10 2>&1 | grep -i "grafana\|eldertree.local" | tail -5
echo ""

echo "9. Testing DNS from within cluster:"
kubectl exec -n pihole deployment/pi-hole -c pihole -- dig @127.0.0.1 grafana.eldertree.local +short 2>&1 || echo "Failed to query DNS"
echo ""

echo "10. Testing Pi-hole external DNS:"
kubectl exec -n pihole deployment/pi-hole -c pihole -- nslookup google.com 127.0.0.1 2>&1 | head -5
echo ""

echo "11. From MacBook - ARP entry for 192.168.2.201:"
arp -a | grep "192.168.2.201" || echo "No ARP entry found"
echo ""

echo "12. From MacBook - Ping test:"
ping -c 2 -W 2 192.168.2.201 2>&1 | tail -3 || echo "Ping failed"
echo ""

echo "13. From MacBook - DNS query to Pi-hole:"
nslookup grafana.eldertree.local 192.168.2.201 2>&1 | head -10 || echo "DNS query failed"
echo ""

echo "=== Summary ==="
echo ""
SVC_IP=$(kubectl get svc -n pihole pi-hole -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "none")
echo "Service LoadBalancer IP: $SVC_IP"
echo ""

if ping -c 1 -W 1 192.168.2.201 > /dev/null 2>&1; then
    echo "✅ Pi-hole IP (192.168.2.201) is reachable from MacBook"
else
    echo "❌ Pi-hole IP (192.168.2.201) is NOT reachable from MacBook"
    echo "   → MetalLB may not be advertising on the correct interface"
    echo "   → Check L2Advertisement interfaces configuration"
fi
echo ""

DNS_RESULT=$(nslookup grafana.eldertree.local 192.168.2.201 2>&1 | grep -i "Address:" | tail -1 | awk '{print $2}' || echo "")
if [ -n "$DNS_RESULT" ] && [ "$DNS_RESULT" != "" ]; then
    echo "✅ grafana.eldertree.local resolves via Pi-hole: $DNS_RESULT"
else
    echo "❌ grafana.eldertree.local does NOT resolve via Pi-hole"
    echo "   → ExternalDNS may not have created the record"
    echo "   → Or Pi-hole is not reachable"
fi
echo ""
