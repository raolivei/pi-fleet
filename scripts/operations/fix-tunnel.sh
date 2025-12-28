#!/bin/bash
# Diagnose and fix Cloudflare Tunnel issues
#
# Usage:
#   ./scripts/operations/fix-tunnel.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_FLEET_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

echo "🔍 Diagnosing Cloudflare Tunnel..."
echo ""

# Check if namespace exists
echo "1. Checking namespace..."
if ! kubectl get namespace cloudflare-tunnel &>/dev/null; then
    echo "   ❌ Namespace 'cloudflare-tunnel' does not exist"
    echo "   📝 Creating namespace..."
    kubectl create namespace cloudflare-tunnel
    echo "   ✅ Namespace created"
else
    echo "   ✅ Namespace exists"
fi
echo ""

# Check if ExternalSecret exists
echo "2. Checking ExternalSecret..."
if ! kubectl get externalsecret cloudflared-credentials -n cloudflare-tunnel &>/dev/null; then
    echo "   ❌ ExternalSecret 'cloudflared-credentials' does not exist"
    echo "   📝 Applying ExternalSecret..."
    kubectl apply -k "$PI_FLEET_DIR/clusters/eldertree/dns-services/cloudflare-tunnel"
    echo "   ✅ ExternalSecret applied"
else
    echo "   ✅ ExternalSecret exists"
    # Check status
    ES_STATUS=$(kubectl get externalsecret cloudflared-credentials -n cloudflare-tunnel -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    if [ "$ES_STATUS" != "True" ]; then
        echo "   ⚠️  ExternalSecret not ready (status: $ES_STATUS)"
        echo "   📋 Checking details..."
        kubectl describe externalsecret cloudflared-credentials -n cloudflare-tunnel | grep -A 10 "Status\|Conditions\|Events" || true
    else
        echo "   ✅ ExternalSecret is ready"
    fi
fi
echo ""

# Check if secret exists
echo "3. Checking Kubernetes secret..."
if ! kubectl get secret cloudflared-credentials -n cloudflare-tunnel &>/dev/null; then
    echo "   ❌ Secret 'cloudflared-credentials' does not exist"
    echo "   ⚠️  This should be created by External Secrets Operator"
    echo "   📋 Checking ExternalSecret status..."
    kubectl get externalsecret cloudflared-credentials -n cloudflare-tunnel -o yaml | grep -A 20 "status:" || true
else
    echo "   ✅ Secret exists"
    # Check if token is present
    if kubectl get secret cloudflared-credentials -n cloudflare-tunnel -o jsonpath='{.data.token}' &>/dev/null | grep -q .; then
        echo "   ✅ Token is present in secret"
    else
        echo "   ❌ Token is missing from secret"
    fi
fi
echo ""

# Check Vault secret
echo "4. Checking Vault secret..."
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$VAULT_POD" ]; then
    echo "   ❌ Vault pod not found"
else
    VAULT_STATUS=$(kubectl exec -n vault $VAULT_POD -- vault status 2>&1 | grep "Sealed" | awk '{print $2}' || echo "true")
    if [ "$VAULT_STATUS" = "true" ]; then
        echo "   ❌ Vault is sealed"
        echo "   💡 Unseal Vault first: cd $PI_FLEET_DIR && ./scripts/operations/unseal-vault.sh"
    else
        echo "   ✅ Vault is unsealed"
        if kubectl exec -n vault $VAULT_POD -- vault kv get secret/pi-fleet/cloudflare-tunnel/token &>/dev/null; then
            echo "   ✅ Tunnel token exists in Vault"
        else
            echo "   ❌ Tunnel token missing from Vault"
            echo "   💡 Store token: cd $PI_FLEET_DIR/terraform && ./scripts/store-tunnel-token.sh"
        fi
    fi
fi
echo ""

# Check deployment
echo "5. Checking deployment..."
if ! kubectl get deployment cloudflared -n cloudflare-tunnel &>/dev/null; then
    echo "   ❌ Deployment 'cloudflared' does not exist"
    echo "   📝 Applying deployment..."
    kubectl apply -k "$PI_FLEET_DIR/clusters/eldertree/dns-services/cloudflare-tunnel"
    echo "   ✅ Deployment applied"
else
    echo "   ✅ Deployment exists"
    # Check replicas
    DESIRED=$(kubectl get deployment cloudflared -n cloudflare-tunnel -o jsonpath='{.spec.replicas}')
    READY=$(kubectl get deployment cloudflared -n cloudflare-tunnel -o jsonpath='{.status.readyReplicas}')
    if [ "$READY" != "$DESIRED" ]; then
        echo "   ⚠️  Deployment not ready (Ready: $READY/$DESIRED)"
    else
        echo "   ✅ Deployment is ready ($READY/$DESIRED replicas)"
    fi
fi
echo ""

# Check pods
echo "6. Checking pods..."
PODS=$(kubectl get pods -n cloudflare-tunnel -l app=cloudflared -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
if [ -z "$PODS" ]; then
    echo "   ❌ No pods found"
else
    for POD in $PODS; do
        POD_STATUS=$(kubectl get pod $POD -n cloudflare-tunnel -o jsonpath='{.status.phase}')
        echo "   Pod: $POD (Status: $POD_STATUS)"
        
        if [ "$POD_STATUS" != "Running" ]; then
            echo "   ⚠️  Pod is not running"
            echo "   📋 Recent events:"
            kubectl describe pod $POD -n cloudflare-tunnel | grep -A 5 "Events:" || true
            echo ""
            echo "   📋 Recent logs:"
            kubectl logs $POD -n cloudflare-tunnel --tail=20 || true
        else
            echo "   ✅ Pod is running"
            echo "   📋 Recent logs:"
            kubectl logs $POD -n cloudflare-tunnel --tail=10 || true
        fi
    done
fi
echo ""

# Summary and next steps
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if everything is working
ALL_GOOD=true

if ! kubectl get namespace cloudflare-tunnel &>/dev/null; then
    ALL_GOOD=false
fi

if ! kubectl get externalsecret cloudflared-credentials -n cloudflare-tunnel &>/dev/null; then
    ALL_GOOD=false
fi

if ! kubectl get secret cloudflared-credentials -n cloudflare-tunnel &>/dev/null; then
    ALL_GOOD=false
fi

READY_PODS=$(kubectl get pods -n cloudflare-tunnel -l app=cloudflared -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null | wc -w)
if [ "$READY_PODS" -eq 0 ]; then
    ALL_GOOD=false
fi

if [ "$ALL_GOOD" = true ]; then
    echo "✅ Tunnel appears to be configured correctly"
    echo ""
    echo "If you're still seeing errors, check:"
    echo "  1. Tunnel token is valid: kubectl logs -n cloudflare-tunnel deployment/cloudflared"
    echo "  2. Tunnel configuration in Cloudflare Dashboard"
    echo "  3. DNS records are correct"
    echo ""
    echo "To view live logs:"
    echo "  kubectl logs -n cloudflare-tunnel deployment/cloudflared -f"
else
    echo "⚠️  Issues detected. Common fixes:"
    echo ""
    echo "1. If token is missing from Vault:"
    echo "   cd $PI_FLEET_DIR/terraform && ./scripts/store-tunnel-token.sh"
    echo ""
    echo "2. If ExternalSecret is not syncing:"
    echo "   kubectl get externalsecrets -n cloudflare-tunnel"
    echo "   kubectl describe externalsecret cloudflared-credentials -n cloudflare-tunnel"
    echo ""
    echo "3. If pod is not starting:"
    echo "   kubectl describe pod -n cloudflare-tunnel -l app=cloudflared"
    echo "   kubectl logs -n cloudflare-tunnel -l app=cloudflared"
    echo ""
    echo "4. To restart the deployment:"
    echo "   kubectl rollout restart deployment/cloudflared -n cloudflare-tunnel"
fi

echo ""

