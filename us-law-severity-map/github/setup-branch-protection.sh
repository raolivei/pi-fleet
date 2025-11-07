#!/bin/bash
#
# Setup Branch Protection Rules for Terraform Workflow
#
# This script configures branch protection on 'main' branch to ensure:
# 1. Terraform Plan must pass before merge
# 2. Terraform Apply must pass before merge (manual trigger required)
# 3. Pull requests are required
# 4. Conversations must be resolved
#
# Prerequisites:
# - GitHub CLI (gh) installed
# - Authenticated with repo admin access
#
# Usage:
#   ./github/setup-branch-protection.sh

set -e

echo "🔒 Setting up branch protection rules..."
echo ""

# Configuration
REPO_OWNER="raolivei"
REPO_NAME="us-law-severity-map"
BRANCH="main"

# Required status checks
STATUS_CHECKS="Terraform Plan,Terraform Apply"

echo "📋 Configuration:"
echo "  Repository: ${REPO_OWNER}/${REPO_NAME}"
echo "  Branch: ${BRANCH}"
echo "  Required checks: ${STATUS_CHECKS}"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI (gh) is not installed"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Error: Not authenticated with GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI authenticated"
echo ""

# Apply branch protection using GitHub API
echo "🔧 Applying branch protection rules..."
echo ""

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/${REPO_OWNER}/${REPO_NAME}/branches/${BRANCH}/protection" \
  --input - << 'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Terraform Plan", "Terraform Apply"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
EOF

echo ""
echo "✅ Branch protection rules configured successfully!"
echo ""
echo "📝 Rules applied:"
echo "  ✅ Pull requests required"
echo "  ✅ Status checks required:"
echo "     - Terraform Plan"
echo "     - Terraform Apply"
echo "  ✅ Branches must be up to date"
echo "  ✅ Conversation resolution required"
echo "  ✅ Linear history enforced"
echo "  ✅ Force push disabled"
echo "  ✅ Branch deletion disabled"
echo "  ✅ Rules apply to administrators"
echo ""
echo "🎯 Result:"
echo "  PRs cannot be merged until 'Terraform Apply' status check passes!"
echo "  This enforces manual apply before merge."
echo ""
echo "🌐 View settings at:"
echo "  https://github.com/${REPO_OWNER}/${REPO_NAME}/settings/branches"
echo ""
echo "✨ Done!"

