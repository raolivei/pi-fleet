# Terraform GitHub Actions Setup

This document explains how to configure GitHub Actions to run Terraform workflows.

## Required GitHub Secrets

The Terraform workflow requires the following secrets to be configured in your GitHub repository:

### Terraform Cloud Secrets (for Remote State)

1. **`TF_API_TOKEN`**
   - Description: Terraform Cloud API token for remote state backend
   - How to get:
     1. Go to [Terraform Cloud](https://app.terraform.io/app/settings/tokens)
     2. Click "Create an API token"
     3. Give it a description (e.g., "GitHub Actions")
     4. Copy the token (you won't be able to see it again)
   - **Required**: Yes (for remote state persistence in CI)

2. **`TF_CLOUD_ORGANIZATION`**
   - Description: Your Terraform Cloud organization name
   - How to get:
     1. Go to [Terraform Cloud](https://app.terraform.io)
     2. Your organization name is shown in the URL or top navigation
     3. Or create a new organization if you don't have one (free tier available)
   - **Required**: Yes (for remote state persistence in CI)

### Cloudflare Secrets

1. **`CLOUDFLARE_API_TOKEN`**
   - Description: Cloudflare API token for managing DNS and tunnels
   - How to get:
     1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
     2. Click "Create Token"
     3. Use "Edit zone DNS" template or create custom token with:
        - Permissions: `Zone` → `DNS` → `Edit`
        - Permissions: `Zone` → `Zone` → `Read`
        - Permissions: `Account` → `Cloudflare Tunnel` → `Edit` (for tunnels)
        - Zone Resources: Include `eldertree.xyz`
     4. Copy the token (you won't be able to see it again)

2. **`CLOUDFLARE_ZONE_ID`**
   - Description: Cloudflare Zone ID for `eldertree.xyz`
   - How to get:
     - Cloudflare Dashboard → Select `eldertree.xyz` → Overview → Zone ID (right sidebar)
     - Or via API: `curl -X GET "https://api.cloudflare.com/client/v4/zones?name=eldertree.xyz" -H "Authorization: Bearer YOUR_API_TOKEN"`

3. **`CLOUDFLARE_ACCOUNT_ID`**
   - Description: Cloudflare Account ID (required for tunnels)
   - How to get:
     - Cloudflare Dashboard → Right sidebar → Account ID
     - Or via API: `curl -X GET "https://api.cloudflare.com/client/v4/accounts" -H "Authorization: Bearer YOUR_API_TOKEN"`

4. **`PUBLIC_IP`** (optional)
   - Description: Public IP address for DNS A records
   - How to get: Your public IP address (can be dynamic)

## Setting Up Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret listed above

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

## What Gets Managed

The workflow manages all Terraform resources defined in the `terraform/` directory:
- Cloudflare DNS records (A, CNAME)
- Cloudflare Tunnel and configuration
- Any other resources you add to Terraform

**Note**: Resources that require SSH access (like k3s installation) will fail in CI but won't block other resources from being managed.

## Troubleshooting

### Workflow Fails with "No configuration files"
- Ensure Terraform files are in `terraform/` directory
- Check that workflow is triggered by changes to `terraform/**` files

### Workflow Fails with "Missing required variable"
- Verify all required secrets are configured in GitHub repository settings
- Check secret names match exactly (case-sensitive)

### Plan Shows Errors
- Check Cloudflare API token has correct permissions
- Verify Zone ID and Account ID are correct
- Ensure domain is added to Cloudflare account

### Apply Fails
- Review plan output in workflow logs
- Check Cloudflare API rate limits
- Verify no manual changes were made in Cloudflare Dashboard

## Security Notes

- Secrets are encrypted and only accessible during workflow runs
- Never commit secrets to the repository
- Use environment-specific secrets for different environments (dev, prod)
- Rotate API tokens regularly

