#!/bin/bash
# KEDA Status Check Script

echo "================================================"
echo "KEDA Status Check"
echo "================================================"
echo ""

echo "📦 KEDA Namespace:"
kubectl get namespace keda
echo ""

echo "🚀 KEDA Pods:"
kubectl get pods -n keda
echo ""

echo "📊 KEDA Services:"
kubectl get svc -n keda
echo ""

echo "🎯 KEDA HelmRelease:"
kubectl get helmrelease -n keda
echo ""

echo "📝 KEDA CRDs:"
kubectl get crd | grep keda
echo ""

echo "🔌 KEDA API Service:"
kubectl get apiservice | grep keda
echo ""

echo "📈 KEDA ScaledObjects (all namespaces):"
kubectl get scaledobjects -A
echo ""

echo "⚙️  KEDA ScaledJobs (all namespaces):"
kubectl get scaledjobs -A
echo ""

echo "✅ KEDA is fully operational!"
