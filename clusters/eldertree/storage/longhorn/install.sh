#!/bin/bash
# Longhorn Pre-flight Checks and Installation Helpers
# This script performs pre-flight checks and provides helper functions
# Longhorn is deployed via Flux GitOps - this script does NOT install directly

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Longhorn Pre-flight Checks ==="
echo ""

# Check if running as root (some checks need root)
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Some checks require root privileges${NC}"
    echo "   Run with sudo for complete checks"
    echo ""
fi

# 1. Check kernel modules
echo "1️⃣ Checking kernel modules..."
MISSING_MODULES=()

if ! lsmod | grep -q "iscsi"; then
    MISSING_MODULES+=("iscsi")
fi

if ! lsmod | grep -q "nvme"; then
    MISSING_MODULES+=("nvme")
fi

if [ ${#MISSING_MODULES[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ Required kernel modules loaded${NC}"
    echo "   - iscsi: $(lsmod | grep iscsi | head -1 | awk '{print $1}')"
    echo "   - nvme: $(lsmod | grep nvme | head -1 | awk '{print $1}')"
else
    echo -e "${RED}❌ Missing kernel modules: ${MISSING_MODULES[*]}${NC}"
    echo "   Install with: sudo apt-get install -y open-iscsi"
    echo "   Load module: sudo modprobe open-iscsi"
fi

# 2. Check mount point
echo ""
echo "2️⃣ Checking /mnt/longhorn mount point..."
if [ -d "/mnt/longhorn" ]; then
    if mountpoint -q /mnt/longhorn 2>/dev/null; then
        MOUNT_INFO=$(df -h /mnt/longhorn | tail -1)
        AVAILABLE=$(echo "$MOUNT_INFO" | awk '{print $4}')
        echo -e "${GREEN}✅ /mnt/longhorn is mounted${NC}"
        echo "   Available: $AVAILABLE"
        
        # Check if it's ext4
        FSTYPE=$(findmnt -n -o FSTYPE /mnt/longhorn 2>/dev/null || echo "unknown")
        if [ "$FSTYPE" = "ext4" ]; then
            echo -e "${GREEN}✅ Filesystem is ext4${NC}"
        else
            echo -e "${YELLOW}⚠️  Filesystem is $FSTYPE (expected ext4)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  /mnt/longhorn directory exists but is not mounted${NC}"
        echo "   Create mount point and add to /etc/fstab"
    fi
else
    echo -e "${RED}❌ /mnt/longhorn directory does not exist${NC}"
    echo "   Create with: sudo mkdir -p /mnt/longhorn"
fi

# 3. Check disk space
echo ""
echo "3️⃣ Checking disk space..."
if [ -d "/mnt/longhorn" ] && mountpoint -q /mnt/longhorn 2>/dev/null; then
    AVAILABLE_GB=$(df -BG /mnt/longhorn | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$AVAILABLE_GB" -ge 50 ]; then
        echo -e "${GREEN}✅ Sufficient space available: ${AVAILABLE_GB}GB${NC}"
    else
        echo -e "${YELLOW}⚠️  Low disk space: ${AVAILABLE_GB}GB (recommend 50GB+)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Cannot check disk space - mount point not available${NC}"
fi

# 4. Check k3s
echo ""
echo "4️⃣ Checking k3s..."
if command -v k3s &> /dev/null || [ -f /usr/local/bin/k3s ]; then
    if sudo systemctl is-active --quiet k3s 2>/dev/null || sudo systemctl is-active --quiet k3s-agent 2>/dev/null; then
        echo -e "${GREEN}✅ k3s is running${NC}"
    else
        echo -e "${RED}❌ k3s is not running${NC}"
        echo "   Start with: sudo systemctl start k3s"
    fi
else
    echo -e "${RED}❌ k3s is not installed${NC}"
fi

# 5. Check Flux
echo ""
echo "5️⃣ Checking Flux..."
if command -v kubectl &> /dev/null; then
    if kubectl get namespace flux-system &> /dev/null; then
        FLUX_CONTROLLERS=$(kubectl get pods -n flux-system --no-headers 2>/dev/null | grep -c Running || echo "0")
        if [ "$FLUX_CONTROLLERS" -gt 0 ]; then
            echo -e "${GREEN}✅ Flux is operational${NC}"
            echo "   Running controllers: $FLUX_CONTROLLERS"
        else
            echo -e "${RED}❌ Flux controllers are not running${NC}"
        fi
    else
        echo -e "${RED}❌ Flux namespace not found${NC}"
        echo "   Bootstrap Flux first"
    fi
else
    echo -e "${YELLOW}⚠️  kubectl not found - cannot check Flux${NC}"
fi

# 6. Check node labels
echo ""
echo "6️⃣ Checking node labels..."
if command -v kubectl &> /dev/null; then
    NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$NODES" -gt 0 ]; then
        echo -e "${GREEN}✅ Found $NODES node(s)${NC}"
        kubectl get nodes --show-labels 2>/dev/null | while read -r line; do
            NODE_NAME=$(echo "$line" | awk '{print $1}')
            echo "   - $NODE_NAME"
        done
    else
        echo -e "${RED}❌ No nodes found${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  kubectl not found - cannot check nodes${NC}"
fi

echo ""
echo "=== Pre-flight Checks Complete ==="
echo ""
echo "📋 Next Steps:"
echo "1. Ensure all checks pass (fix any issues above)"
echo "2. Commit and push Longhorn manifests to git repository"
echo "3. Flux will automatically deploy Longhorn"
echo "4. Monitor deployment: kubectl get pods -n longhorn-system -w"
echo "5. Run verify.sh after deployment completes"
echo ""
echo "🔧 Useful Commands:"
echo "  kubectl get helmrelease -n longhorn-system"
echo "  kubectl get pods -n longhorn-system"
echo "  kubectl logs -n longhorn-system -l app=longhorn-manager"
echo ""

