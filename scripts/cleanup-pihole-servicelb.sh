#!/bin/bash
# Cleanup script to remove K3s ServiceLB DaemonSets for Pi-hole
# This is a temporary workaround until ServiceLB is disabled globally in K3s
#
# Usage: ./cleanup-pihole-servicelb.sh

set -e

NAMESPACE="kube-system"
SERVICE_NAME="pi-hole"
SERVICE_NAMESPACE="pihole"

echo "🔍 Checking for Pi-hole ServiceLB DaemonSets..."

# Get all svclb DaemonSets for pi-hole
DAEMONSETS=$(kubectl get daemonset -n "${NAMESPACE}" -o json | \
  jq -r ".items[] | select(.metadata.labels.\"svccontroller.k3s.cattle.io/svcname\" == \"${SERVICE_NAME}\" and .metadata.labels.\"svccontroller.k3s.cattle.io/svcnamespace\" == \"${SERVICE_NAMESPACE}\") | .metadata.name")

if [ -z "${DAEMONSETS}" ]; then
  echo "✅ No Pi-hole ServiceLB DaemonSets found"
  exit 0
fi

echo "⚠️  Found ServiceLB DaemonSets:"
echo "${DAEMONSETS}" | while read -r ds; do
  echo "  - ${ds}"
done

echo ""
echo "🗑️  Deleting ServiceLB DaemonSets..."

echo "${DAEMONSETS}" | while read -r ds; do
  echo "  Deleting ${ds}..."
  kubectl delete daemonset "${ds}" -n "${NAMESPACE}" || true
done

echo ""
echo "✅ Cleanup complete"
echo ""
echo "⚠️  Note: These DaemonSets may be recreated by K3s ServiceLB controller."
echo "   To permanently fix this, disable ServiceLB globally in K3s:"
echo "   1. Run: ansible-playbook ansible/playbooks/disable-k3s-servicelb.yml"
echo "   2. Or manually add '--disable servicelb' to K3s service files on all nodes"








