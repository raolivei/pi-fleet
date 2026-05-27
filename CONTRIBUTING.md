# Contributing to Pi Fleet

## Git Branching Strategy

When working on this repository, ALWAYS follow this branching workflow.

### Branch Naming Convention

Create branches with these prefixes based on work type:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `feat/` or `feature/` | New features | `feat/user-authentication` |
| `fix/` | Bug fixes | `fix/login-error` |
| `chore/` | Maintenance tasks | `chore/update-dependencies` |
| `docs/` | Documentation only | `docs/api-readme` |
| `refactor/` | Code refactoring | `refactor/database-queries` |
| `infra/` | Infrastructure changes | `infra/pi-fleet` |
| `test/` | Test additions/changes | `test/user-service` |

### Workflow Rules

1. **NEVER commit directly to `main`**
2. **Always create a feature branch** for any work
3. **Push feature branches to remote** for backup and collaboration
4. **Keep branches focused** - one feature/fix/task per branch
5. **Merge to main only when truly complete** (stable, tested, documented)

### Example Workflow

```bash
# Start new work
git checkout main
git pull
git checkout -b feat/my-new-feature

# Work, commit, push
git add .
git commit -m "feat: Add my new feature"
git push origin feat/my-new-feature

# Continue iterating on the branch
git commit -m "feat: Improve feature implementation"
git push origin feat/my-new-feature

# When feature is complete, stable, and tested
git checkout main
git pull
git merge feat/my-new-feature
git push origin main
git branch -d feat/my-new-feature  # Optional: delete local branch
```

### Branch Lifecycle

- **Keep feature branches** until work is fully complete and tested
- **Push regularly** to remote for backup and visibility
- **Merge to main** only when production-ready
- **Delete branches** after successful merge (optional locally; remote is automatic — see below)

### Remote branch cleanup (GitHub)

This repo has **Settings → General → Pull Requests → Automatically delete head branches** enabled (`deleteBranchOnMerge`).

| Event | Remote head branch |
|-------|-------------------|
| PR **merged** | Deleted automatically by GitHub |
| PR **closed** without merge | **Not** deleted — remove manually if obsolete |

```bash
# After closing a superseded PR, delete the remote branch if you no longer need it:
git push origin --delete <branch-name>

# Or delete from the PR page: "Delete branch" (shown after merge; for closed PRs use the branches UI)
```

**Local cleanup** after merge:

```bash
git checkout main && git pull
git branch -d feat/my-feature          # safe delete if merged
git fetch --prune origin               # drop stale remote-tracking refs
```

Org-wide convention: [workspace-config/docs/PROJECT_CONVENTIONS.md](../workspace-config/docs/PROJECT_CONVENTIONS.md#github-pull-request-branch-cleanup).

### GitHub Actions and Dependabot

- **`main` Terraform** ([`terraform.yml`](.github/workflows/terraform.yml)) should stay green — badge on [README](README.md).
- **Dependabot PRs** do not receive Actions secrets. After rotating Cloudflare or Terraform Cloud credentials:
  1. Update Vault (`secret/pi-fleet/terraform/*`) and/or GitHub Actions secrets.
  2. Run `./scripts/sync-github-terraform-secrets-from-vault.sh --app dependabot` (Cloudflare from Vault; pass `TF_API_TOKEN=…` for Terraform Cloud — not stored in Vault by default).
- A red Terraform check on an old Dependabot PR that was **merged anyway** (e.g. `actions/checkout` bump) is safe to ignore if **`main` is green**.

### Commit Message Convention

Follow conventional commits format:

```
<type>: <description>

[optional body]

[optional footer]
```

**Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `chore:` - Maintenance tasks
- `refactor:` - Code refactoring
- `test:` - Adding/updating tests
- `infra:` - Infrastructure changes

**Examples:**
```bash
feat: Add k3s cluster setup with Terraform
fix: Resolve cgroup v2 memory controller issue
docs: Update README with cluster access instructions
chore: Update Terraform providers to latest versions
infra: Configure monitoring stack
```

## Why This Approach?

- **Main stays stable** - Always deployable/production-ready
- **Feature isolation** - Work independently without conflicts
- **Easy rollback** - Can revert entire features if needed
- **Clear history** - See what work was done and when
- **Collaboration** - Multiple people can work on different branches

## Current Active Branches

- `main` - Production-ready code
- `infra/pi-fleet` - Infrastructure setup and configuration (work in progress)
- `feat/atlantis-k3s-setup` - Atlantis integration (work in progress)

## Questions?

If you have questions about the workflow, check existing branches for examples or ask the maintainer.

---

**Remember: Feature branches allow iteration without polluting main. Main should always be stable and production-ready.**

