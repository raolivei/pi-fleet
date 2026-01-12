#!/bin/bash
# Quick script to fix node-1 dual IP issue
# Run this when node-1 is accessible

echo "Fixing node-1 dual IP issue..."
ssh raolivei@node-1 'bash -s' < "$(dirname "$0")/fix-node-1-dual-ip.sh"


