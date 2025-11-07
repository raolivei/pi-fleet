#!/bin/bash
set -e

# Update kubeconfig cluster/context names to "eldertree"
KUBECONFIG_PATH="${1:-$HOME/.kube/config-eldertree}"

if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "Error: Kubeconfig not found at $KUBECONFIG_PATH"
    exit 1
fi

echo "Updating kubeconfig at $KUBECONFIG_PATH..."

# Simple approach: update all references except in users section
perl -i.bak -pe '
    # Track if we are in users section
    $in_users = 1 if /^users:/;
    $in_users = 0 if /^(clusters|contexts|apiVersion|kind|preferences|current-context):/;
    
    # Replace unless in users section
    unless ($in_users) {
        s/^(\s+)name: default$/${1}name: eldertree/;
        s/^(\s+)cluster: default$/${1}cluster: eldertree/;
        s/^current-context: default$/current-context: eldertree/;
    }
' "$KUBECONFIG_PATH"

rm -f "${KUBECONFIG_PATH}.bak"

echo "✓ Kubeconfig updated successfully"
echo ""
echo "Cluster and context renamed to 'eldertree'"
echo ""
echo "To use:"
echo "  export KUBECONFIG=$KUBECONFIG_PATH"
echo "  kubectl get nodes"
