#!/bin/bash
# Update local-path provisioner ConfigMap for multi-node cluster
# This script updates the ConfigMap to include node-specific storage paths

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Updating local-path provisioner configuration...${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Check if KUBECONFIG is set
if [ -z "${KUBECONFIG:-}" ]; then
    if [ -f ~/.kube/config-eldertree ]; then
        export KUBECONFIG=~/.kube/config-eldertree
        echo -e "${YELLOW}Using KUBECONFIG=~/.kube/config-eldertree${NC}"
    else
        echo -e "${YELLOW}Warning: KUBECONFIG not set${NC}"
    fi
fi

# Get current node names
echo -e "${GREEN}Current nodes:${NC}"
kubectl get nodes -o custom-columns=NAME:.metadata.name --no-headers

# Build node path map
# Main node (eldertree) uses SATA/NVMe
# Other nodes use SD card storage
MAIN_NODE="eldertree"
MAIN_NODE_PATHS='["/mnt/nvme/storage","/mnt/sata/storage"]'
DEFAULT_PATH='["/var/lib/rancher/k3s/storage"]'

# Get all node names
NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')

# Build JSON structure
JSON='{"nodePathMap":[{"node":"DEFAULT_PATH_FOR_NON_LISTED_NODES","paths":'$DEFAULT_PATH'}'

# Add main node
JSON="$JSON,{\"node\":\"$MAIN_NODE\",\"paths\":$MAIN_NODE_PATHS}"

# Add worker nodes (if any)
for NODE in $NODES; do
    if [ "$NODE" != "$MAIN_NODE" ]; then
        JSON="$JSON,{\"node\":\"$NODE\",\"paths\":$DEFAULT_PATH}"
    fi
done

JSON="$JSON]}"

# Update ConfigMap
echo -e "${GREEN}Updating ConfigMap...${NC}"
kubectl patch configmap local-path-config -n kube-system \
  --type merge \
  -p "{\"data\":{\"config.json\":$(echo "$JSON" | jq -c .)}}"

echo -e "${GREEN}✅ Configuration updated!${NC}"
echo ""
echo "Current configuration:"
kubectl get configmap local-path-config -n kube-system -o jsonpath='{.data.config\.json}' | jq .

