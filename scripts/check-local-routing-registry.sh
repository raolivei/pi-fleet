#!/usr/bin/env bash
# Verify local routing files include every host in docs/eldertree-local-services.yaml
#
# Usage (from pi-fleet repo root):
#   ./scripts/check-local-routing-registry.sh
#   ./scripts/check-local-routing-registry.sh --fix-hints
#
# Exit 0 if all hosts appear in sync_targets; exit 1 if any missing.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="${ROOT}/docs/eldertree-local-services.yaml"
HINTS=false

if [[ "${1:-}" == "--fix-hints" ]]; then
  HINTS=true
fi

if [[ ! -f "$REGISTRY" ]]; then
  echo "ERROR: registry not found: $REGISTRY" >&2
  exit 1
fi

mapfile -t HOSTS < <(
  awk '/^  - host: / { print $3 }' "$REGISTRY" | sort -u
)

if [[ ${#HOSTS[@]} -eq 0 ]]; then
  echo "ERROR: no hosts parsed from $REGISTRY" >&2
  exit 1
fi

mapfile -t TARGETS < <(
  awk '/^  - / && !/^  - host:/ { gsub(/^  - /, ""); print }' "$REGISTRY"
)

FAIL=0
echo "=== Local routing registry sync (${#HOSTS[@]} hosts) ==="
echo ""

for target_rel in "${TARGETS[@]}"; do
  target="${ROOT}/${target_rel}"
  if [[ ! -f "$target" ]]; then
    echo "FAIL  missing file: $target_rel"
    FAIL=1
    continue
  fi
  missing=()
  for host in "${HOSTS[@]}"; do
    if ! grep -qF "$host" "$target"; then
      missing+=("$host")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "OK    $target_rel"
  else
    echo "FAIL  $target_rel — missing ${#missing[@]} host(s):"
    for h in "${missing[@]}"; do
      echo "        - $h"
    done
    FAIL=1
  fi
done

if [[ $FAIL -ne 0 ]]; then
  echo ""
  if $HINTS; then
    cat <<'EOF'

Fix hints:
  1. Add missing hosts to docs/eldertree-local-hosts-block.txt (TRAEFIK_LB_IP line)
  2. Add to scripts/add-services-to-hosts.sh (inside Eldertree block)
  3. Copy a Caddy block from scripts/Caddyfile (elder.eldertree.local template)
  4. Re-run: ./scripts/check-local-routing-registry.sh

Onboarding guide: docs/ONBOARDING_APP_ROUTING.md
EOF
  fi
  exit 1
fi

# Optional: hosts in sync files but not in registry (drift) — warnings only
set +e
for target_rel in "${TARGETS[@]}"; do
  target="${ROOT}/${target_rel}"
  [[ -f "$target" ]] || continue
  while IFS= read -r line; do
    [[ "$line" =~ \.eldertree\.local ]] || continue
    host=$(echo "$line" | grep -oE '[a-z0-9.-]+\.eldertree\.local' | head -1 || true)
    [[ -z "$host" ]] && continue
    [[ "$host" =~ ^node-[0-9]\.eldertree\.local$ ]] && continue
    found=false
    for h in "${HOSTS[@]}"; do
      [[ "$h" == "$host" ]] && found=true && break
    done
    if ! $found; then
      echo "WARN  $host in $target_rel but not in registry — add to eldertree-local-services.yaml"
    fi
  done < <(grep -E '\.eldertree\.local' "$target" 2>/dev/null || true)
done
set -e

echo "All registry hosts present in sync files."
exit 0
