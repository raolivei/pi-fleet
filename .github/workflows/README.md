# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the pi-fleet project.

## Workflows

### Terraform

**File:** `terraform.yml`

Validates and plans Terraform infrastructure changes. This workflow ensures all Terraform configuration is properly formatted, validated, and planned before merging.

**Triggers:**
- Push to `main` branch (when `terraform/**` files change)
- Pull requests (when `terraform/**` files change)
- Manual workflow dispatch

**What it does:**
1. Initializes Terraform with remote backend (Terraform Cloud)
2. Validates Terraform configuration syntax
3. Checks code formatting (`terraform fmt`)
4. Generates execution plan (shows what would change)
5. Optionally applies changes (manual trigger only)

**Status Check:** `Terraform`

This workflow creates a status check named "Terraform" that must pass before PRs can be merged (when branch protection is enabled).

## Workflow Behavior

### On Pull Requests
- Runs `terraform init`
- Runs `terraform fmt -check` (validates formatting)
- Runs `terraform validate` (validates configuration)
- Runs `terraform plan` (shows what would change)
- **Does NOT apply changes**

### On Push to Main
- Runs all PR checks (plan only)
- **Does NOT automatically apply changes** (prevents failures after merge)

### Manual Apply (Ad-Hoc)
- Go to **Actions** → **Terraform** → **Run workflow**
- Select branch (usually `main`)
- Check **"Apply Terraform changes"** checkbox
- Click **Run workflow**
- This will run plan + apply

**Why manual apply?**
- PRs can be merged safely after plan succeeds
- Apply failures won't block merges
- You control when infrastructure changes are applied

## Setup

For detailed setup instructions, including required GitHub secrets and Terraform Cloud configuration, see [`TERRAFORM_SETUP.md`](TERRAFORM_SETUP.md).

### Quick Setup Checklist

1. Configure GitHub Secrets (see TERRAFORM_SETUP.md):
   - `TF_API_TOKEN`
   - `CLOUDFLARE_API_TOKEN`
   - `CLOUDFLARE_ZONE_ID`
   - `CLOUDFLARE_ACCOUNT_ID`
   - `PUBLIC_IP` (optional)

2. Configure Terraform Cloud workspace:
   - Set execution mode to **"Local"** (not "Remote")
   - Workspace: `pi-fleet-terraform`
   - Organization: `eldertree`

3. Enable branch protection (optional):
   ```bash
   ./github/setup-branch-protection.sh
   ```

## Versioning Strategy

Since pi-fleet is infrastructure-as-code (not a Docker image builder), versioning works differently:

- **VERSION file**: Tracks current project version (e.g., `1.3.0`)
- **Git tags**: Use semantic versioning tags (e.g., `v1.3.0`) for releases
- **CHANGELOG.md**: Documents all changes following [Keep a Changelog](https://keepachangelog.com/) format

**Version consistency:**
- Git tag versions should match VERSION file
- CHANGELOG.md entries should match git tags
- Version increments follow semantic versioning (MAJOR.MINOR.PATCH)

**When to version:**
- Major releases: Significant infrastructure changes or breaking changes
- Minor releases: New features or non-breaking changes
- Patch releases: Bug fixes or small improvements

## Troubleshooting

### Workflow Fails with "No configuration files"
- Ensure Terraform files are in `terraform/` directory
- Check that workflow is triggered by changes to `terraform/**` files

### Workflow Fails with "Missing required variable"
- Verify all required secrets are configured in GitHub repository settings
- Check secret names match exactly (case-sensitive)
- See [`TERRAFORM_SETUP.md`](TERRAFORM_SETUP.md) for detailed secret setup

### Plan Shows Errors
- Check Cloudflare API token has correct permissions
- Verify Zone ID and Account ID are correct
- Ensure domain is added to Cloudflare account

### Apply Fails
- Review plan output in workflow logs
- Check Cloudflare API rate limits
- Verify no manual changes were made in Cloudflare Dashboard

### Status Check Not Appearing
- Ensure workflow file is in `.github/workflows/` directory
- Check workflow syntax is valid YAML
- Verify workflow is triggered by the PR/push event
- Wait a few minutes for GitHub to register the workflow

For more detailed troubleshooting, see [`TERRAFORM_SETUP.md`](TERRAFORM_SETUP.md).

## Security Notes

- Secrets are encrypted and only accessible during workflow runs
- Never commit secrets to the repository
- Use environment-specific secrets for different environments (dev, prod)
- Rotate API tokens regularly
- Branch protection ensures Terraform validation passes before merging

