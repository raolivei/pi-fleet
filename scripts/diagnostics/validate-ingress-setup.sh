#!/bin/bash
# Validate Ingress, Cert-Manager and ExternalDNS setup
# Usage: ./scripts/diagnostics/validate-ingress-setup.sh

set -e

echo "=========================================="
echo "Validating Ingress Setup"
echo "=========================================="
echo ""

# Check if KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
    echo "⚠️  KUBECONFIG not set. Using default: ~/.kube/config-eldertree"
    export KUBECONFIG=~/.kube/config-eldertree
fi

echo "📋 KUBECONFIG: $KUBECONFIG"
echo ""

# =============================================================================
# 1. Traefik Validation
# =============================================================================
echo "🔍 1. Checking Traefik Ingress Controller..."
echo "-------------------------------------------"

if kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik &>/dev/null; then
    TRAEFIK_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$TRAEFIK_PODS" -gt 0 ]; then
        echo "✅ Traefik pods found: $TRAEFIK_PODS"
        kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
    else
        echo "❌ No Traefik pods found"
    fi
else
    echo "❌ Failed to query Traefik pods"
fi

if kubectl get ingressclass traefik &>/dev/null; then
    echo "✅ Traefik IngressClass exists"
    kubectl get ingressclass traefik
else
    echo "❌ Traefik IngressClass not found"
fi

if kubectl get svc -n kube-system traefik &>/dev/null; then
    echo "✅ Traefik service exists"
    kubectl get svc -n kube-system traefik
else
    echo "⚠️  Traefik service not found (may be using different name)"
fi

echo ""

# =============================================================================
# 2. Cert-Manager Validation
# =============================================================================
echo "🔍 2. Checking Cert-Manager..."
echo "-------------------------------------------"

if kubectl get namespace cert-manager &>/dev/null; then
    echo "✅ cert-manager namespace exists"
    
    CERT_MANAGER_PODS=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$CERT_MANAGER_PODS" -gt 0 ]; then
        echo "✅ Cert-Manager pods: $CERT_MANAGER_PODS"
        kubectl get pods -n cert-manager
        echo ""
        echo "Pod status:"
        kubectl get pods -n cert-manager -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready
    else
        echo "❌ No Cert-Manager pods found"
    fi
else
    echo "❌ cert-manager namespace not found"
fi

echo ""
echo "ClusterIssuers:"
if kubectl get clusterissuer &>/dev/null; then
    kubectl get clusterissuer
    echo ""
    echo "ClusterIssuer details:"
    kubectl get clusterissuer -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,MESSAGE:.status.conditions[0].message
else
    echo "❌ No ClusterIssuers found"
fi

echo ""
echo "Certificates:"
CERT_COUNT=$(kubectl get certificates -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$CERT_COUNT" -gt 0 ]; then
    echo "✅ Found $CERT_COUNT certificate(s)"
    kubectl get certificates -A
else
    echo "⚠️  No certificates found (this is OK if no ingress with TLS exists)"
fi

echo ""

# =============================================================================
# 3. ExternalDNS Validation
# =============================================================================
echo "🔍 3. Checking ExternalDNS..."
echo "-------------------------------------------"

if kubectl get namespace external-dns &>/dev/null; then
    echo "✅ external-dns namespace exists"
    
    EXTERNAL_DNS_PODS=$(kubectl get pods -n external-dns --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$EXTERNAL_DNS_PODS" -gt 0 ]; then
        echo "✅ ExternalDNS pods: $EXTERNAL_DNS_PODS"
        kubectl get pods -n external-dns
        echo ""
        echo "Pod status:"
        kubectl get pods -n external-dns -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready
    else
        echo "❌ No ExternalDNS pods found"
        echo ""
        echo "Checking HelmRelease status..."
        if kubectl get helmrelease -n external-dns external-dns &>/dev/null; then
            HELMRELEASE_STATUS=$(kubectl get helmrelease -n external-dns external-dns -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
            if [ "$HELMRELEASE_STATUS" != "True" ]; then
                echo "⚠️  HelmRelease not ready. Checking HelmRepository..."
                if kubectl get helmrepository -n flux-system external-dns &>/dev/null; then
                    REPO_STATUS=$(kubectl get helmrepository -n flux-system external-dns -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
                    if [ "$REPO_STATUS" != "True" ]; then
                        REPO_MESSAGE=$(kubectl get helmrepository -n flux-system external-dns -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
                        echo "❌ HelmRepository 'external-dns' is not ready"
                        echo "   Message: $REPO_MESSAGE"
                        echo ""
                        echo "   This is likely a DNS resolution issue. Check cluster DNS configuration."
                        echo "   Try: kubectl describe helmrepository -n flux-system external-dns"
                    fi
                fi
            fi
        else
            echo "⚠️  HelmRelease 'external-dns' not found in namespace 'external-dns'"
        fi
    fi
else
    echo "❌ external-dns namespace not found"
fi

if kubectl get secret -n external-dns external-dns-tsig-secret &>/dev/null; then
    echo "✅ ExternalDNS TSIG secret exists"
else
    echo "⚠️  ExternalDNS TSIG secret not found"
fi

echo ""

# =============================================================================
# 4. Ingress Resources Validation
# =============================================================================
echo "🔍 4. Checking Ingress Resources..."
echo "-------------------------------------------"

INGRESS_COUNT=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$INGRESS_COUNT" -gt 0 ]; then
    echo "✅ Found $INGRESS_COUNT ingress resource(s)"
    echo ""
    kubectl get ingress -A
    echo ""
    echo "Ingress details (with TLS and annotations):"
    kubectl get ingress -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTS:.spec.rules[*].host,TLS:.spec.tls[*].hosts[0],CLASS:.spec.ingressClassName
else
    echo "⚠️  No ingress resources found"
fi

echo ""

# =============================================================================
# 5. Summary and Recommendations
# =============================================================================
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""

ISSUES=0

# Check Traefik
if ! kubectl get ingressclass traefik &>/dev/null; then
    echo "❌ Traefik IngressClass missing"
    ISSUES=$((ISSUES + 1))
fi

# Check Cert-Manager
if ! kubectl get namespace cert-manager &>/dev/null; then
    echo "❌ Cert-Manager namespace missing"
    ISSUES=$((ISSUES + 1))
elif [ "$CERT_MANAGER_PODS" -eq 0 ]; then
    echo "❌ Cert-Manager pods not running"
    ISSUES=$((ISSUES + 1))
fi

if ! kubectl get clusterissuer selfsigned-cluster-issuer &>/dev/null; then
    echo "⚠️  Self-signed ClusterIssuer not found (may need to deploy cert-manager-issuers)"
fi

# Check ExternalDNS
if ! kubectl get namespace external-dns &>/dev/null; then
    echo "❌ ExternalDNS namespace missing"
    ISSUES=$((ISSUES + 1))
elif [ "$EXTERNAL_DNS_PODS" -eq 0 ]; then
    echo "❌ ExternalDNS pods not running"
    ISSUES=$((ISSUES + 1))
fi

if [ $ISSUES -eq 0 ]; then
    echo "✅ All core components are configured correctly!"
    echo ""
    echo "Next steps:"
    echo "  1. Create an Ingress resource with TLS"
    echo "  2. Verify certificate is created: kubectl get certificates -A"
    echo "  3. Verify DNS record is created: nslookup <hostname>.eldertree.local 192.168.2.83"
    echo "  4. Test access: curl -k https://<hostname>.eldertree.local"
else
    echo "⚠️  Found $ISSUES issue(s). Please review the output above."
fi

echo ""
echo "For detailed documentation, see: docs/INGRESS.md"

