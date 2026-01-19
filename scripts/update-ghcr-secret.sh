#!/bin/bash
# Script to update ghcr-secret in all namespaces for private GHCR package pulls
# Usage: ./update-ghcr-secret.sh YOUR_PAT_TOKEN
#
# Create a PAT at: https://github.com/settings/tokens/new
# Required scope: read:packages
# Or use Fine-grained token with Packages → Read permission

set -e

PAT_TOKEN="$1"
USERNAME="raolivei"
EMAIL="raolivei@users.noreply.github.com"
NAMESPACES=("pitanga" "swimto" "visage")

if [ -z "$PAT_TOKEN" ]; then
  echo "Usage: $0 YOUR_PAT_TOKEN"
  echo ""
  echo "Create a PAT at: https://github.com/settings/tokens/new"
  echo "Required scope: read:packages"
  echo ""
  echo "Or create a Fine-grained token at:"
  echo "https://github.com/settings/personal-access-tokens/new"
  echo "With Packages → Read permission"
  exit 1
fi

echo "Testing token validity..."
if ! curl -sf -H "Authorization: Bearer $PAT_TOKEN" https://ghcr.io/token?service=ghcr.io > /dev/null 2>&1; then
  echo "Warning: Token may not be valid for GHCR. Proceeding anyway..."
fi

for NS in "${NAMESPACES[@]}"; do
  echo "Updating ghcr-secret in namespace: $NS"
  kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username="$USERNAME" \
    --docker-password="$PAT_TOKEN" \
    --docker-email="$EMAIL" \
    -n "$NS" \
    --dry-run=client -o yaml | kubectl apply -f -
done

echo ""
echo "✅ Secrets updated in all namespaces!"
echo ""
echo "To restart failing pods, run:"
echo "  kubectl delete pods -n pitanga -l app=northwaysignal-website"
echo ""
echo "To verify a namespace can pull:"
echo "  kubectl run test-pull --image=ghcr.io/raolivei/northwaysignal-website:latest -n pitanga --rm -it --restart=Never -- echo 'Pull successful!'"
