#!/bin/bash
# Audit script to find hardcoded secrets that should be in Vault
# This helps ensure we're using Vault for all secrets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================="
echo "Secret Audit - Finding Hardcoded Secrets"
echo "=========================================="
echo ""
echo "This script searches for potential hardcoded secrets that should be in Vault"
echo ""

ISSUES=0

# Patterns to search for
PATTERNS=(
    "ghp_[A-Za-z0-9]\{36\}"  # GitHub Personal Access Token
    "ghs_[A-Za-z0-9]\{36\}"  # GitHub App Token
    "gho_[A-Za-z0-9]\{36\}"  # GitHub OAuth Token
    "ghu_[A-Za-z0-9]\{36\}"  # GitHub User Token
    "ghr_[A-Za-z0-9]\{36\}"  # GitHub Refresh Token
    "sk-[A-Za-z0-9]\{32\}"   # OpenAI API Key
    "pk_[A-Za-z0-9]\{32\}"   # Stripe Public Key
    "sk_live_[A-Za-z0-9]\{32\}"  # Stripe Secret Key
    "AIza[0-9A-Za-z_-]\{35\}"  # Google API Key
    "password.*=.*['\"][^'\"]\{8,\}['\"]"  # Hardcoded passwords
    "token.*=.*['\"][A-Za-z0-9]\{20,\}['\"]"  # Hardcoded tokens
    "api[_-]?key.*=.*['\"][A-Za-z0-9]\{20,\}['\"]"  # Hardcoded API keys
    "secret[_-]?key.*=.*['\"][A-Za-z0-9]\{20,\}['\"]"  # Hardcoded secret keys
)

# Directories to exclude
EXCLUDE_DIRS=(
    ".git"
    "node_modules"
    "__pycache__"
    ".venv"
    "venv"
    "env"
    ".env"
    "dist"
    "build"
    ".next"
    ".cache"
)

# File extensions to check
INCLUDE_EXTENSIONS=(
    ".sh"
    ".yaml"
    ".yml"
    ".py"
    ".js"
    ".ts"
    ".md"
    ".tf"
    ".tfvars"
)

echo "Searching for hardcoded secrets..."
echo ""

# Build find command with exclusions
FIND_CMD="find \"$REPO_ROOT\" -type f"
for exclude in "${EXCLUDE_DIRS[@]}"; do
    FIND_CMD="$FIND_CMD -not -path \"*/$exclude/*\""
done

# Check each pattern
for pattern in "${PATTERNS[@]}"; do
    echo "Checking pattern: $pattern"
    
    # Use find with grep
    while IFS= read -r file; do
        # Check if file has one of our extensions
        EXT="${file##*.}"
        if [[ " ${INCLUDE_EXTENSIONS[@]} " =~ " .$EXT " ]] || [[ "$file" == *".env"* ]] || [[ "$file" == *"secret"* ]]; then
            # Skip if it's a template or example file
            if [[ "$file" != *".example"* ]] && [[ "$file" != *".template"* ]] && [[ "$file" != *"template"* ]]; then
                MATCHES=$(grep -n "$pattern" "$file" 2>/dev/null || true)
                if [ -n "$MATCHES" ]; then
                    echo ""
                    echo "⚠️  Found potential secret in: $file"
                    echo "$MATCHES" | while IFS= read -r line; do
                        echo "   $line"
                    done
                    ISSUES=$((ISSUES + 1))
                fi
            fi
        fi
    done < <(eval "$FIND_CMD" | head -1000)  # Limit to first 1000 files for performance
done

echo ""
echo "=========================================="
echo "Audit Summary"
echo "=========================================="
echo "Issues found: $ISSUES"
echo ""

if [ "$ISSUES" -eq 0 ]; then
    echo "✅ No hardcoded secrets found!"
    echo ""
    echo "Remember:"
    echo "  - All secrets should be in Vault"
    echo "  - Use External Secrets Operator to sync to Kubernetes"
    echo "  - Never commit secrets to Git"
    exit 0
else
    echo "⚠️  Found $ISSUES potential hardcoded secrets"
    echo ""
    echo "Recommendations:"
    echo "  1. Move secrets to Vault"
    echo "  2. Use Vault paths in scripts (read from Vault)"
    echo "  3. Use External Secrets Operator for Kubernetes"
    echo "  4. Remove hardcoded values from files"
    echo ""
    echo "See: docs/VAULT_SECRETS_MANAGEMENT.md"
    exit 1
fi


