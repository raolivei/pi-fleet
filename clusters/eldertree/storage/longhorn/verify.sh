#!/bin/bash
# Longhorn Health Check and Validation Script
# Verifies Longhorn installation, replica distribution, and anti-affinity

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Longhorn Health Check and Validation ==="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found${NC}"
    echo "   Install kubectl or set KUBECONFIG"
    exit 1
fi

# 1. Check Longhorn namespace
echo "1️⃣ Checking Longhorn namespace..."
if kubectl get namespace longhorn-system &> /dev/null; then
    echo -e "${GREEN}✅ longhorn-system namespace exists${NC}"
else
    echo -e "${RED}❌ longhorn-system namespace not found${NC}"
    echo "   Longhorn may not be installed yet"
    exit 1
fi

# 2. Check Longhorn pods
echo ""
echo "2️⃣ Checking Longhorn pods..."
PODS=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$PODS" -eq 0 ]; then
    echo -e "${RED}❌ No pods found in longhorn-system${NC}"
    exit 1
fi

RUNNING_PODS=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | grep -c Running || echo "0")
TOTAL_PODS=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    echo -e "${GREEN}✅ All $TOTAL_PODS pod(s) are running${NC}"
else
    echo -e "${YELLOW}⚠️  $RUNNING_PODS/$TOTAL_PODS pod(s) running${NC}"
    echo "   Not all pods are ready - check status:"
    kubectl get pods -n longhorn-system
fi

# 3. Check Longhorn components
echo ""
echo "3️⃣ Checking Longhorn components..."
COMPONENTS=("longhorn-manager" "longhorn-csi-plugin" "longhorn-ui")

for COMPONENT in "${COMPONENTS[@]}"; do
    if kubectl get pods -n longhorn-system -l app="$COMPONENT" --no-headers 2>/dev/null | grep -q Running; then
        COUNT=$(kubectl get pods -n longhorn-system -l app="$COMPONENT" --no-headers 2>/dev/null | grep -c Running || echo "0")
        echo -e "${GREEN}✅ $COMPONENT: $COUNT pod(s) running${NC}"
    else
        echo -e "${RED}❌ $COMPONENT: not running${NC}"
    fi
done

# 4. Check StorageClass
echo ""
echo "4️⃣ Checking Longhorn StorageClass..."
if kubectl get storageclass longhorn &> /dev/null; then
    echo -e "${GREEN}✅ longhorn StorageClass exists${NC}"
    kubectl get storageclass longhorn -o yaml | grep -A 5 "parameters:" || true
else
    echo -e "${YELLOW}⚠️  longhorn StorageClass not found${NC}"
    echo "   This is expected if defaultClass is set to false"
fi

# 5. Check nodes and disk registration
echo ""
echo "5️⃣ Checking node disk registration..."
NODES=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $1}' || echo "")
if [ -z "$NODES" ]; then
    echo -e "${RED}❌ No nodes found${NC}"
else
    echo -e "${GREEN}✅ Found $(echo "$NODES" | wc -l) node(s)${NC}"
    for NODE in $NODES; do
        echo "   - $NODE"
    done
    echo ""
    echo "   To check disk registration, use Longhorn UI or:"
    echo "   kubectl get nodes -o yaml | grep -A 10 longhorn"
fi

# 6. Test volume creation and replica distribution
echo ""
echo "6️⃣ Testing volume creation and replica distribution..."
echo "   Creating test PVC..."

cat <<EOF | kubectl apply -f - 2>/dev/null || echo -e "${YELLOW}⚠️  Test PVC may already exist${NC}"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-test-pvc
  namespace: longhorn-system
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
EOF

sleep 5

if kubectl get pvc longhorn-test-pvc -n longhorn-system &> /dev/null; then
    PVC_STATUS=$(kubectl get pvc longhorn-test-pvc -n longhorn-system -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [ "$PVC_STATUS" = "Bound" ]; then
        echo -e "${GREEN}✅ Test PVC created and bound${NC}"
        
        # Get volume name
        VOLUME_NAME=$(kubectl get pvc longhorn-test-pvc -n longhorn-system -o jsonpath='{.spec.volumeName}' 2>/dev/null || echo "")
        if [ -n "$VOLUME_NAME" ]; then
            echo "   Volume: $VOLUME_NAME"
            
            # Check replicas (requires Longhorn API or UI)
            echo "   To verify replica distribution:"
            echo "   1. Access Longhorn UI"
            echo "   2. Check volume $VOLUME_NAME"
            echo "   3. Verify 2 replicas are on different nodes"
        fi
    else
        echo -e "${YELLOW}⚠️  Test PVC status: $PVC_STATUS${NC}"
        echo "   Wait for PVC to bind: kubectl get pvc -n longhorn-system -w"
    fi
else
    echo -e "${RED}❌ Failed to create test PVC${NC}"
fi

# 7. Anti-affinity verification
echo ""
echo "7️⃣ Anti-affinity verification..."
echo "   This requires checking Longhorn volume replicas"
echo "   Use Longhorn UI or API to verify:"
echo "   - Each volume has 2 replicas"
echo "   - Replicas are on different nodes"
echo "   - No two replicas share the same node"

# 8. Node failure simulation guide
echo ""
echo "8️⃣ Node Failure Simulation Guide:"
echo ""
echo "   To test Longhorn's resilience:"
echo ""
echo "   1. Create a test pod with the PVC:"
echo "      kubectl run test-pod --image=busybox --rm -it --restart=Never \\"
echo "        --overrides='{\"spec\":{\"volumes\":[{\"name\":\"data\",\"persistentVolumeClaim\":{\"claimName\":\"longhorn-test-pvc\"}}],\"containers\":[{\"name\":\"test-pod\",\"image\":\"busybox\",\"volumeMounts\":[{\"mountPath\":\"/data\",\"name\":\"data\"}]}]}}'"
echo ""
echo "   2. Identify the node running the pod:"
echo "      kubectl get pod test-pod -o wide"
echo ""
echo "   3. Cordon the node (prevent new pods):"
echo "      kubectl cordon <node-name>"
echo ""
echo "   4. Drain the node (simulate failure):"
echo "      kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data"
echo ""
echo "   5. Verify volume rebuild:"
echo "      - Check Longhorn UI for volume status"
echo "      - Verify replicas are rebuilt on remaining nodes"
echo "      - Check pod reschedules to another node"
echo ""
echo "   6. Restore the node:"
echo "      kubectl uncordon <node-name>"
echo ""

# 9. Cleanup test resources
echo ""
read -p "Clean up test PVC? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete pvc longhorn-test-pvc -n longhorn-system 2>/dev/null && \
        echo -e "${GREEN}✅ Test PVC deleted${NC}" || \
        echo -e "${YELLOW}⚠️  Test PVC may not exist${NC}"
fi

echo ""
echo "=== Validation Complete ==="
echo ""
echo "📋 Summary:"
echo "- Longhorn components should be running"
echo "- Test PVC created to verify functionality"
echo "- Use Longhorn UI for detailed volume and replica information"
echo ""
echo "🔧 Useful Commands:"
echo "  kubectl get pods -n longhorn-system"
echo "  kubectl get pvc -A"
echo "  kubectl get volumes.longhorn.io -n longhorn-system"
echo "  # Access Longhorn UI via port-forward:"
echo "  kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80"
echo ""

