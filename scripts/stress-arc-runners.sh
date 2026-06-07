#!/usr/bin/env bash
# Dispatch workflow_dispatch across raolivei repos to stress repo-scoped ARC scale sets.
# Only dispatches repos listed in ARC_REPOS (repos with a HelmRelease scale set deployed).
set -euo pipefail

# Repos with deployed scale sets — update as phases roll out
ARC_REPOS="${ARC_REPOS:-ollie pi-fleet-blog elder canopy swimTO personal-website northwaysignal-website nima eldertree-docs}"

has_repo() {
  local want=$1
  for r in $ARC_REPOS; do
    [[ "$r" == "$want" ]] && return 0
  done
  return 1
}

dispatch() {
  local repo=$1 workflow=$2
  if ! has_repo "$repo"; then
    echo "  - ${repo} → ${workflow} (no scale set — skipped)"
    return 0
  fi
  if gh workflow run "$workflow" --repo "raolivei/${repo}" 2>/dev/null; then
    echo "  ✓ ${repo} → ${workflow}"
  else
    echo "  ✗ ${repo} → ${workflow} (dispatch failed or no workflow_dispatch)"
  fi
}

echo "Stress test — ARC repos: ${ARC_REPOS}"
echo "Dispatching parallel workflows..."
echo ""

# Lightweight jobs first
dispatch pi-fleet-blog "Deploy Blog"
dispatch eldertree-docs "Deploy Docs"
dispatch personal-website "Security Scanning"

# Docker builds — native ARM64 on Pi (heavier)
dispatch canopy "Build and Push Docker Images"
dispatch swimTO "Build and Push Docker Images"
dispatch personal-website "Build and Push Docker Image"
dispatch nima "Build and Push Docker Images"
dispatch elder "Build and Push Docker Image"
dispatch northwaysignal-website "Build and Push Docker Image"

# ollie: serial pipeline — workflow_dispatch on build-publish
dispatch ollie "Build and Publish"

echo ""
echo "Dispatched. Monitor with: pi-fleet/scripts/monitor-arc-runners.sh"
echo "GitHub Actions tabs under each repo in ARC_REPOS"
