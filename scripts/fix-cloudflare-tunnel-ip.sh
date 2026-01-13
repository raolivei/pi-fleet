#!/bin/bash
# Fix Cloudflare Tunnel IP configuration
# Updates the tunnel to use the correct Traefik ClusterIP

set -e

echo "🔍 Getting current Traefik ClusterIP..."
TRAEFIK_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.spec.clusterIP}')

if [ -z "$TRAEFIK_IP" ]; then
    echo "❌ Error: Could not get Traefik ClusterIP"
    exit 1
fi

echo "✅ Traefik ClusterIP: $TRAEFIK_IP"
echo ""
echo "📝 To fix the Cloudflare Tunnel configuration:"
echo ""
echo "1. Go to Cloudflare Dashboard: https://dash.cloudflare.com"
echo "2. Navigate to: Zero Trust → Networks → Tunnels"
echo "3. Click on the 'eldertree' tunnel"
echo "4. Click 'Configure' next to your connector"
echo "5. Update the ingress rules:"
echo ""
echo "   For 'swimto.eldertree.xyz' with path '/':"
echo "   Change service from: http://10.43.81.2:80"
echo "   To: http://${TRAEFIK_IP}:80"
echo ""
echo "   For 'swimto.eldertree.xyz' with path '/api/*':"
echo "   Change service from: http://10.43.81.2:80"
echo "   To: http://${TRAEFIK_IP}:80"
echo ""
echo "6. Save the configuration"
echo ""
echo "7. Wait 30-60 seconds for the tunnel to reconnect"
echo ""
echo "8. Test: curl -I https://swimto.eldertree.xyz"
echo ""
echo "Alternatively, you can update via Cloudflare API if you have the API token."
echo "See: https://developers.cloudflare.com/api/operations/cloudflare-tunnel-update-cloudflare-tunnel-configuration"










