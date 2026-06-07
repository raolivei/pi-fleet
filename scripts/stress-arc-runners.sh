#!/usr/bin/env bash
# Dispatch workflow_dispatch across raolivei repos to stress ARC at maxRunners.
# Prerequisites: org-wide ARC (pi-fleet#223) + self-hosted defaults (github-workflows#16).
set -euo pipefail

echo "Dispatching parallel workflows (light + docker builds)..."

dispatch() {
  local repo=$1 workflow=$2
  if gh workflow run "$workflow" --repo "raolivei/${repo}" 2>/dev/null; then
    echo "  ✓ ${repo} → ${workflow}"
  else
    echo "  ✗ ${repo} → ${workflow} (skipped)"
  fi
}

# Prefer lightweight jobs first so queue fills even if DinD builds are slow
dispatch pi-fleet-blog "Deploy Blog"
dispatch eldertree-docs "Deploy Docs"
dispatch fragment "CI"
dispatch personal-website "Security Scanning"
dispatch nima "Pull Request Checks" 2>/dev/null || true

# Docker builds — native ARM64 on Pi (heavier)
dispatch canopy "Build and Push Docker Images"
dispatch swimTO "Build and Push Docker Images"
dispatch personal-website "Build and Push Docker Image"
dispatch pitanga-website "Build and Push Docker Images"
dispatch journey "Build and Push Docker Images"
dispatch nima "Build and Push Docker Images"
dispatch elder "Build and Push Docker Image"
dispatch northwaysignal-website "Build and Push Docker Image"

echo ""
echo "Dispatched. Monitor with: pi-fleet/scripts/monitor-arc-runners.sh"
echo "GitHub: https://github.com/raolivei/ollie/actions (and other repo Actions tabs)"
