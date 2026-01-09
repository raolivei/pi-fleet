#!/bin/bash
# Recovery script for a single node booted from SD card
# Usage: ./recover-node-from-sd.sh node-1

set -e

NODE=${1:-node-1}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_FLEET_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_DIR="$PI_FLEET_DIR/ansible"
INVENTORY="$ANSIBLE_DIR/inventory/hosts.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Node Recovery: $NODE ===${NC}"
echo ""

# Check if node is reachable
echo "Checking if $NODE is accessible..."
if ! ansible "$NODE" -i "$INVENTORY" -m ping &>/dev/null; then
    echo -e "${RED}❌ $NODE is not accessible${NC}"
    echo "Make sure:"
    echo "  1. SD card is inserted"
    echo "  2. NVMe was removed (temporarily)"
    echo "  3. Node booted completely (wait 1-2 minutes)"
    echo "  4. SSH is working"
    exit 1
fi

echo -e "${GREEN}✅ $NODE is accessible${NC}"
echo ""

# Apply boot reliability fixes
echo "Applying boot reliability fixes..."
cd "$ANSIBLE_DIR" || exit 1

if ansible-playbook playbooks/fix-boot-reliability.yml --limit "$NODE" -i "$INVENTORY"; then
    echo -e "${GREEN}✅ Fixes applied successfully${NC}"
else
    echo -e "${RED}❌ Failed to apply fixes${NC}"
    exit 1
fi

echo ""

# Verify fixes
echo "Verifying applied fixes..."

echo -n "  - fstab has nofail: "
if ansible "$NODE" -i "$INVENTORY" -m shell -a "grep -q nofail /etc/fstab" --become &>/dev/null; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
fi

echo -n "  - Root unlocked: "
ROOT_STATUS=$(ansible "$NODE" -i "$INVENTORY" -m shell -a "passwd -S root" --become 2>/dev/null | grep -o "L\|P\|NP" | head -1)
if [[ "$ROOT_STATUS" != "L" ]]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
fi

echo ""
echo -e "${GREEN}=== Recovery Complete ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Test reboot: ansible $NODE -i $INVENTORY -m reboot --become"
echo "  2. Wait 2 minutes and verify: ansible $NODE -i $INVENTORY -m ping"
echo "  3. If it boots correctly, node is recovered"
echo "  4. Repeat process for next node"
