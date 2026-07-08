#!/usr/bin/env bash
#
# Canopy Deployment Verification Script
# Checks all resources are healthy before considering deployment complete
#
set -euo pipefail

NAMESPACE="canopy"
TIMEOUT=300  # 5 minutes

echo "=========================================="
echo "Canopy Deployment Verification"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_step() {
    local step=$1
    echo -e "${YELLOW}[CHECK]${NC} $step"
}

success() {
    local msg=$1
    echo -e "${GREEN}[OK]${NC} $msg"
}

error() {
    local msg=$1
    echo -e "${RED}[ERROR]${NC} $msg"
    exit 1
}

# 1. Check namespace exists
check_step "Namespace exists"
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    success "Namespace $NAMESPACE exists"
else
    error "Namespace $NAMESPACE not found"
fi

# 2. Check ExternalSecrets are synced
check_step "ExternalSecrets synced"
externalsecrets=(
    "canopy-secrets"
    "ghcr-secret"
    "canopy-basic-auth"
    "canopy-cloudflare-origin-cert"
)

for es in "${externalsecrets[@]}"; do
    status=$(kubectl get externalsecret "$es" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    if [[ "$status" == "True" ]]; then
        success "ExternalSecret $es is synced"
    else
        error "ExternalSecret $es is not ready (status: $status)"
    fi
done

# 3. Check secrets exist
check_step "Kubernetes secrets exist"
secrets=(
    "canopy-secrets"
    "ghcr-secret"
    "canopy-basic-auth"
    "canopy-cloudflare-origin-tls"
)

for secret in "${secrets[@]}"; do
    if kubectl get secret "$secret" -n "$NAMESPACE" &>/dev/null; then
        success "Secret $secret exists"
    else
        error "Secret $secret not found"
    fi
done

# 4. Check PostgreSQL StatefulSet
check_step "PostgreSQL StatefulSet ready"
kubectl wait --for=condition=ready pod -l component=postgres -n "$NAMESPACE" --timeout="${TIMEOUT}s" || error "PostgreSQL pod not ready"
success "PostgreSQL is ready"

# 5. Check HelmRelease status
check_step "HelmRelease deployed"
helm_status=$(kubectl get helmrelease canopy -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
if [[ "$helm_status" == "True" ]]; then
    success "HelmRelease canopy is deployed"
else
    error "HelmRelease canopy is not ready (status: $helm_status)"
fi

# 6. Check API deployment
check_step "Canopy API ready"
kubectl wait --for=condition=available deployment/canopy-api -n "$NAMESPACE" --timeout="${TIMEOUT}s" || error "API deployment not available"
success "Canopy API is ready"

# 7. Check Frontend deployment
check_step "Canopy Frontend ready"
kubectl wait --for=condition=available deployment/canopy-frontend -n "$NAMESPACE" --timeout="${TIMEOUT}s" || error "Frontend deployment not available"
success "Canopy Frontend is ready"

# 8. Check Redis deployment
check_step "Canopy Redis ready"
kubectl wait --for=condition=available deployment/canopy-redis -n "$NAMESPACE" --timeout="${TIMEOUT}s" || error "Redis deployment not available"
success "Canopy Redis is ready"

# 9. Check all pods are running
check_step "All pods running"
not_running=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$not_running" -eq 0 ]]; then
    success "All pods are running"
else
    error "$not_running pods are not running"
fi

# 10. Check API health endpoint
check_step "API health endpoint"
if kubectl get service canopy-api -n "$NAMESPACE" &>/dev/null; then
    # Port-forward in background and test
    kubectl port-forward -n "$NAMESPACE" service/canopy-api 18000:8000 &>/dev/null &
    PF_PID=$!
    sleep 2

    if curl -sf http://localhost:18000/v1/health &>/dev/null; then
        success "API health endpoint responding"
    else
        error "API health endpoint not responding"
    fi

    kill $PF_PID 2>/dev/null || true
else
    error "API service not found"
fi

# 11. Check Ingress
check_step "Ingress configured"
ingresses=$(kubectl get ingress -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$ingresses" -gt 0 ]]; then
    success "Found $ingresses ingress route(s)"
else
    error "No ingress routes found"
fi

# 12. Summary
echo ""
echo "=========================================="
echo -e "${GREEN}All checks passed!${NC}"
echo "=========================================="
echo ""
echo "Deployment URLs:"
echo "  - Local:  https://canopy.eldertree.local"
echo "  - Public: https://canopy.eldertree.xyz"
echo ""
echo "Next steps:"
echo "  1. Run migrations: kubectl apply -f clusters/eldertree/canopy/migration-job.yaml"
echo "  2. Access the UI at one of the URLs above"
echo "  3. Check logs: kubectl logs -n canopy -l app=canopy -f"
echo ""
