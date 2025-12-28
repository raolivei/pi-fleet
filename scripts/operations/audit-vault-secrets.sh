#!/bin/bash
set -e

# Audit Vault Secrets Configuration
# This script audits all Kubernetes workloads to ensure they're properly configured
# to receive secrets from Vault via External Secrets Operator

echo "=== Vault Secrets Audit ==="
echo ""

# Check if KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
    echo "⚠️  KUBECONFIG not set. Setting to eldertree cluster..."
    export KUBECONFIG=~/.kube/config-eldertree
fi

# Check kubectl access
if ! kubectl cluster-info &>/dev/null; then
    echo "❌ Cannot access cluster. Check KUBECONFIG."
    exit 1
fi

echo "✅ Cluster access verified"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track issues
ISSUES=0
WARNINGS=0

# Function to check if ExternalSecret exists
check_externalsecret() {
    local namespace=$1
    local secret_name=$2
    
    if kubectl get externalsecret "$secret_name" -n "$namespace" &>/dev/null; then
        # Check if it's syncing
        local status=$(kubectl get externalsecret "$secret_name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        if [ "$status" = "True" ]; then
            echo -e "${GREEN}  ✅ ExternalSecret '$secret_name' exists and is syncing${NC}"
            return 0
        else
            echo -e "${YELLOW}  ⚠️  ExternalSecret '$secret_name' exists but status: $status${NC}"
            ((WARNINGS++))
            return 1
        fi
    else
        echo -e "${RED}  ❌ ExternalSecret '$secret_name' NOT FOUND${NC}"
        ((ISSUES++))
        return 1
    fi
}

# Function to check if Kubernetes secret exists
check_k8s_secret() {
    local namespace=$1
    local secret_name=$2
    
    if kubectl get secret "$secret_name" -n "$namespace" &>/dev/null; then
        echo -e "${GREEN}  ✅ Kubernetes secret '$secret_name' exists${NC}"
        return 0
    else
        echo -e "${RED}  ❌ Kubernetes secret '$secret_name' NOT FOUND${NC}"
        ((ISSUES++))
        return 1
    fi
}

# Function to audit namespace
audit_namespace() {
    local namespace=$1
    echo "📦 Namespace: $namespace"
    
    # Get all workloads that might use secrets
    local deployments=$(kubectl get deployments -n "$namespace" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    local statefulsets=$(kubectl get statefulsets -n "$namespace" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    local cronjobs=$(kubectl get cronjobs -n "$namespace" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    local jobs=$(kubectl get jobs -n "$namespace" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    # Track secrets referenced in this namespace
    declare -A secrets_used
    
    # Check deployments
    if [ -n "$deployments" ]; then
        for deploy in $deployments; do
            echo "  🔍 Checking Deployment: $deploy"
            
            # Get secret references
            local secret_refs=$(kubectl get deployment "$deploy" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[*].env[*].valueFrom.secretKeyRef.name}' 2>/dev/null || echo "")
            local secret_volumes=$(kubectl get deployment "$deploy" -n "$namespace" -o jsonpath='{.spec.template.spec.volumes[*].secret.secretName}' 2>/dev/null || echo "")
            
            # Check init containers too
            local init_secret_refs=$(kubectl get deployment "$deploy" -n "$namespace" -o jsonpath='{.spec.template.spec.initContainers[*].env[*].valueFrom.secretKeyRef.name}' 2>/dev/null || echo "")
            
            # Combine all secret references
            local all_secrets="$secret_refs $secret_volumes $init_secret_refs"
            
            if [ -n "$all_secrets" ]; then
                for secret in $all_secrets; do
                    if [ -n "$secret" ] && [ "$secret" != "null" ]; then
                        secrets_used["$secret"]=1
                        echo "    📝 References secret: $secret"
                    fi
                done
            else
                echo "    ℹ️  No secrets referenced"
            fi
            
            # Check replica count
            local replicas=$(kubectl get deployment "$deploy" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
            if [ "$replicas" = "0" ]; then
                echo -e "    ${YELLOW}⚠️  Scaled to zero (replicas: 0)${NC}"
            fi
        done
    fi
    
    # Check statefulsets
    if [ -n "$statefulsets" ]; then
        for sts in $statefulsets; do
            echo "  🔍 Checking StatefulSet: $sts"
            
            local secret_refs=$(kubectl get statefulset "$sts" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[*].env[*].valueFrom.secretKeyRef.name}' 2>/dev/null || echo "")
            local secret_volumes=$(kubectl get statefulset "$sts" -n "$namespace" -o jsonpath='{.spec.template.spec.volumes[*].secret.secretName}' 2>/dev/null || echo "")
            local init_secret_refs=$(kubectl get statefulset "$sts" -n "$namespace" -o jsonpath='{.spec.template.spec.initContainers[*].env[*].valueFrom.secretKeyRef.name}' 2>/dev/null || echo "")
            
            local all_secrets="$secret_refs $secret_volumes $init_secret_refs"
            
            if [ -n "$all_secrets" ]; then
                for secret in $all_secrets; do
                    if [ -n "$secret" ] && [ "$secret" != "null" ]; then
                        secrets_used["$secret"]=1
                        echo "    📝 References secret: $secret"
                    fi
                done
            else
                echo "    ℹ️  No secrets referenced"
            fi
            
            local replicas=$(kubectl get statefulset "$sts" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
            if [ "$replicas" = "0" ]; then
                echo -e "    ${YELLOW}⚠️  Scaled to zero (replicas: 0)${NC}"
            fi
        done
    fi
    
    # Check cronjobs
    if [ -n "$cronjobs" ]; then
        for cj in $cronjobs; do
            echo "  🔍 Checking CronJob: $cj"
            
            local secret_refs=$(kubectl get cronjob "$cj" -n "$namespace" -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[*].env[*].valueFrom.secretKeyRef.name}' 2>/dev/null || echo "")
            local secret_volumes=$(kubectl get cronjob "$cj" -n "$namespace" -o jsonpath='{.spec.jobTemplate.spec.template.spec.volumes[*].secret.secretName}' 2>/dev/null || echo "")
            
            local all_secrets="$secret_refs $secret_volumes"
            
            if [ -n "$all_secrets" ]; then
                for secret in $all_secrets; do
                    if [ -n "$secret" ] && [ "$secret" != "null" ]; then
                        secrets_used["$secret"]=1
                        echo "    📝 References secret: $secret"
                    fi
                done
            else
                echo "    ℹ️  No secrets referenced"
            fi
        done
    fi
    
    # Check jobs
    if [ -n "$jobs" ]; then
        for job in $jobs; do
            echo "  🔍 Checking Job: $job"
            
            local secret_refs=$(kubectl get job "$job" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[*].env[*].valueFrom.secretKeyRef.name}' 2>/dev/null || echo "")
            local secret_volumes=$(kubectl get job "$job" -n "$namespace" -o jsonpath='{.spec.template.spec.volumes[*].secret.secretName}' 2>/dev/null || echo "")
            
            local all_secrets="$secret_refs $secret_volumes"
            
            if [ -n "$all_secrets" ]; then
                for secret in $all_secrets; do
                    if [ -n "$secret" ] && [ "$secret" != "null" ]; then
                        secrets_used["$secret"]=1
                        echo "    📝 References secret: $secret"
                    fi
                done
            else
                echo "    ℹ️  No secrets referenced"
            fi
        done
    fi
    
    # Verify ExternalSecrets and Kubernetes secrets for each referenced secret
    if [ ${#secrets_used[@]} -gt 0 ]; then
        echo ""
        echo "  🔐 Verifying secrets:"
        for secret_name in "${!secrets_used[@]}"; do
            echo "    Secret: $secret_name"
            check_externalsecret "$namespace" "$secret_name"
            check_k8s_secret "$namespace" "$secret_name"
        done
    else
        echo "  ℹ️  No secrets referenced in this namespace"
    fi
    
    echo ""
}

# Main audit
echo "🔍 Auditing all namespaces..."
echo ""

# Get all namespaces (excluding system namespaces)
NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E '^(kube-|default$|local-path-storage$)' || echo "")

if [ -z "$NAMESPACES" ]; then
    echo "❌ No namespaces found"
    exit 1
fi

# Audit each namespace
for ns in $NAMESPACES; do
    audit_namespace "$ns"
done

# Check External Secrets Operator status
echo "=== External Secrets Operator Status ==="
if kubectl get deployment external-secrets -n external-secrets &>/dev/null; then
    local eso_ready=$(kubectl get deployment external-secrets -n external-secrets -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local eso_desired=$(kubectl get deployment external-secrets -n external-secrets -o jsonpath='{.status.replicas}' 2>/dev/null || echo "0")
    if [ "$eso_ready" = "$eso_desired" ] && [ "$eso_desired" != "0" ]; then
        echo -e "${GREEN}✅ External Secrets Operator is running ($eso_ready/$eso_desired replicas)${NC}"
    else
        echo -e "${YELLOW}⚠️  External Secrets Operator: $eso_ready/$eso_desired replicas ready${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}❌ External Secrets Operator deployment not found${NC}"
    ((ISSUES++))
fi

# Check ClusterSecretStore
echo ""
echo "=== ClusterSecretStore Status ==="
if kubectl get clustersecretstore vault &>/dev/null; then
    echo -e "${GREEN}✅ ClusterSecretStore 'vault' exists${NC}"
else
    echo -e "${RED}❌ ClusterSecretStore 'vault' NOT FOUND${NC}"
    ((ISSUES++))
fi

# Summary
echo ""
echo "=== Audit Summary ==="
if [ $ISSUES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    exit 0
elif [ $ISSUES -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Audit completed with $WARNINGS warning(s)${NC}"
    exit 0
else
    echo -e "${RED}❌ Audit found $ISSUES issue(s) and $WARNINGS warning(s)${NC}"
    exit 1
fi

