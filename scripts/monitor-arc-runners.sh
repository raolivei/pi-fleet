#!/usr/bin/env bash
# Live babysitter for Eldertree ARC runners — run during load tests.
set -euo pipefail

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"
INTERVAL="${INTERVAL:-15}"
MAX_RUNNERS="${MAX_RUNNERS:-6}"

while true; do
  clear
  echo "=== ARC monitor $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo ""

  echo "--- AutoscalingRunnerSet ---"
  kubectl --kubeconfig="$KUBECONFIG" get autoscalingrunnerset -n arc-runners -o custom-columns=\
NAME:.metadata.name,MIN:.spec.minRunners,MAX:.spec.maxRunners,CURRENT:.status.currentRunners,PENDING:.status.pendingEphemeralRunners,RUNNING:.status.runningEphemeralRunners 2>/dev/null || true

  echo ""
  echo "--- Runner pods ---"
  kubectl --kubeconfig="$KUBECONFIG" get pods -n arc-runners -l actions.github.com/scale-set-name=ollie-eldertree \
    -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[0].ready,STATUS:.status.phase,NODE:.spec.nodeName,AGE:.metadata.creationTimestamp 2>/dev/null || \
    kubectl --kubeconfig="$KUBECONFIG" get pods -n arc-runners 2>/dev/null

  RUNNER_COUNT=$(kubectl --kubeconfig="$KUBECONFIG" get pods -n arc-runners --field-selector=status.phase=Running -o name 2>/dev/null | grep -c runner || true)
  echo ""
  echo "Running runner pods: ${RUNNER_COUNT}/${MAX_RUNNERS}"

  echo ""
  echo "--- Node CPU (actual usage) ---"
  kubectl --kubeconfig="$KUBECONFIG" top nodes 2>/dev/null || echo "(metrics-server unavailable)"

  echo ""
  echo "--- GitHub runners (ollie repo) ---"
  gh api repos/raolivei/ollie/actions/runners --jq '.runners[] | "\(.name) busy=\(.busy) status=\(.status)"' 2>/dev/null || echo "(org/repo API unavailable)"

  echo ""
  echo "--- Queued/in-progress runs (sample) ---"
  for repo in ollie canopy swimTO personal-website pi-fleet-blog eldertree-docs; do
    gh run list --repo "raolivei/${repo}" --limit 2 --json status,conclusion,name,workflowName \
      -q '.[] | select(.status=="queued" or .status=="in_progress") | "\(.workflowName): \(.status)"' 2>/dev/null | sed "s/^/  ${repo}: /" || true
  done

  echo ""
  echo "Refresh every ${INTERVAL}s — Ctrl+C to stop"
  sleep "$INTERVAL"
done
