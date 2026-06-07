#!/usr/bin/env bash
# Live babysitter for Eldertree ARC runners — run during load tests.
set -euo pipefail

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
INTERVAL="${INTERVAL:-15}"
# Repos with repo-scoped scale sets (override for phased rollout)
REPOS="${REPOS:-ollie pi-fleet-blog elder github-workflows canopy swimTO personal-website northwaysignal-website nima eldertree-docs}"

while true; do
  clear
  echo "=== ARC monitor $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo ""

  echo "--- AutoscalingRunnerSet ---"
  kubectl --kubeconfig="$KUBECONFIG" get autoscalingrunnerset -n arc-runners -o custom-columns=\
NAME:.metadata.name,MIN:.spec.minRunners,MAX:.spec.maxRunners,CURRENT:.status.currentRunners,PENDING:.status.pendingEphemeralRunners,RUNNING:.status.runningEphemeralRunners 2>/dev/null || true

  echo ""
  echo "--- Listeners ---"
  kubectl --kubeconfig="$KUBECONFIG" get autoscalinglistener -n arc-controller -o custom-columns=\
NAME:.metadata.name,URL:.spec.githubConfigUrl,PHASE:.status.phase 2>/dev/null || true

  echo ""
  echo "--- Runner pods ---"
  kubectl --kubeconfig="$KUBECONFIG" get pods -n arc-runners \
    -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[0].ready,STATUS:.status.phase,NODE:.spec.nodeName,AGE:.metadata.creationTimestamp 2>/dev/null || \
    kubectl --kubeconfig="$KUBECONFIG" get pods -n arc-runners 2>/dev/null

  RUNNER_COUNT=$(kubectl --kubeconfig="$KUBECONFIG" get pods -n arc-runners --field-selector=status.phase=Running -o name 2>/dev/null | grep -c runner || true)
  echo ""
  echo "Running runner pods: ${RUNNER_COUNT}"

  echo ""
  echo "--- Node CPU (actual usage) ---"
  kubectl --kubeconfig="$KUBECONFIG" top nodes 2>/dev/null || echo "(metrics-server unavailable)"

  echo ""
  echo "--- GitHub runners (by repo) ---"
  for repo in $REPOS; do
    gh api "repos/raolivei/${repo}/actions/runners" --jq ".runners[] | \"${repo}: \(.name) busy=\(.busy) status=\(.status)\"" 2>/dev/null || echo "  ${repo}: (API unavailable)"
  done

  echo ""
  echo "--- Queued/in-progress runs (sample) ---"
  for repo in $REPOS; do
    gh run list --repo "raolivei/${repo}" --limit 2 --json status,conclusion,name,workflowName \
      -q '.[] | select(.status=="queued" or .status=="in_progress") | "\(.workflowName): \(.status)"' 2>/dev/null | sed "s/^/  ${repo}: /" || true
  done

  echo ""
  echo "Refresh every ${INTERVAL}s — Ctrl+C to stop"
  sleep "$INTERVAL"
done
