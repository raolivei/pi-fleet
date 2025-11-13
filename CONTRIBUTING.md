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
- **Delete branches** after successful merge (optional, but recommended for cleanup)

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

