# GHCR: bolao-claude-web package access

Production bolao uses `ghcr.io/raolivei/bolao-web`. The scratch deploy must use a **separate** package:

`ghcr.io/raolivei/bolao-claude-web`

## Symptom

CI workflow **Build bolao-claude Web** fails at push:

```text
403 Forbidden … ghcr.io/v2/raolivei/bolao-claude-web/blobs/…
```

Build succeeds; only the registry push is denied.

## Cause

The `bolao-claude-web` GHCR package was likely created by (or linked to) a different GitHub repo
(e.g. a `bolao-claude` repo URL in ARC runner config). `GITHUB_TOKEN` from `raolivei/bolao` cannot
write until the package grants this repository access.

**Do not** publish scratch images as `bolao-web:claude-*` — that shares the production package.

## Fix (one-time, GitHub UI)

1. Open https://github.com/orgs/raolivei/packages
2. Find container package **`bolao-claude-web`**
   - If missing, skip to step 4 (first successful push after permissions will create it)
3. **Package settings** → **Manage Actions access** → **Add repository** → `raolivei/bolao` → role **Write**
4. Optional: enable **Inherit access from repository**
5. Re-run workflow: Actions → **Build bolao-claude Web** → `ref=feat/p2-core-game-loop`

## Verify

```bash
# After push succeeds
export KUBECONFIG=~/.kube/config-eldertree
kubectl set image deployment/bolao-claude-web -n bolao-claude \
  bolao-claude-web=ghcr.io/raolivei/bolao-claude-web:v0.1.3
kubectl rollout status deployment/bolao-claude-web -n bolao-claude
```

Flux ImagePolicy in `bolao-claude` namespace tracks `bolao-claude-web` semver `>=0.1.0 <1.0.0`.

## Build workflow

Defined in `raolivei/bolao`: `.github/workflows/build-bolao-claude.yml` (workflow_dispatch).
