#!/bin/bash

# Update /etc/hosts with Pi Fleet service entries
CLUSTER_IP="192.168.2.83"

# Services to add
SERVICES=(
    "canopy.eldertree.local"
    "pihole.eldertree.local"
)

echo "Updating /etc/hosts with Pi Fleet service entries..."
echo ""

for service in "${SERVICES[@]}"; do
    if grep -q "$service" /etc/hosts; then
        echo "  ✓ $service already exists"
    else
        echo "  + Adding $service"
        echo "$CLUSTER_IP  $service" | sudo tee -a /etc/hosts > /dev/null
    fi
done

echo ""
echo "Done! Testing DNS resolution..."

# Test resolution
for service in "${SERVICES[@]}"; do
    if ping -c 1 -W 1 "$service" > /dev/null 2>&1; then
        echo "  ✓ $service resolves correctly"
    else
        echo "  ⚠ $service may need a moment to resolve"
    fi
done

echo ""
echo "You can now access:"
for service in "${SERVICES[@]}"; do
    echo "  • https://$service"
done

