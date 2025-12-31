#!/bin/bash
# Fetch detailed PR information from GitHub API

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/blog-analysis"

mkdir -p "$OUTPUT_DIR"

cd "$PROJECT_ROOT"

# Check if gh CLI is available
if command -v gh &> /dev/null; then
    echo "Using GitHub CLI (gh) to fetch PR details..."
    USE_GH_CLI=true
elif [ -n "$GITHUB_TOKEN" ]; then
    echo "Using GitHub API with token..."
    USE_GH_CLI=false
else
    echo "Warning: GitHub CLI (gh) not found and GITHUB_TOKEN not set."
    echo "Install GitHub CLI: brew install gh"
    echo "Or set GITHUB_TOKEN environment variable"
    exit 1
fi

# Get repository info
REPO=$(git remote get-url origin 2>/dev/null | sed -E 's/.*github.com[:/]([^/]+\/[^/]+)(\.git)?$/\1/')
if [ -z "$REPO" ]; then
    echo "Error: Could not determine GitHub repository"
    exit 1
fi

echo "Repository: $REPO"
echo ""

# Extract PR numbers from git history
PR_NUMBERS=$(git log --all --format="%s %b" | grep -oE '#[0-9]+' | sed 's/#//' | sort -u -n)

if [ -z "$PR_NUMBERS" ]; then
    echo "No PR numbers found in git history"
    exit 0
fi

echo "Found PR numbers: $PR_NUMBERS"
echo ""

# Fetch PR details
cat > "$OUTPUT_DIR/pr-details-github.md" << EOF
# Pull Request Details from GitHub

Repository: $REPO
Fetched: $(date)

EOF

for pr_num in $PR_NUMBERS; do
    echo "Fetching PR #$pr_num..."
    
    if [ "$USE_GH_CLI" = true ]; then
        # Use GitHub CLI
        pr_data=$(gh pr view "$pr_num" --json title,body,state,mergedAt,createdAt,author,labels,reviews,comments --repo "$REPO" 2>/dev/null || echo "")
        
        if [ -z "$pr_data" ]; then
            echo "  ⚠️  PR #$pr_num not found or not accessible"
            continue
        fi
        
        title=$(echo "$pr_data" | jq -r '.title // "N/A"')
        body=$(echo "$pr_data" | jq -r '.body // "N/A"')
        state=$(echo "$pr_data" | jq -r '.state // "N/A"')
        merged_at=$(echo "$pr_data" | jq -r '.mergedAt // "N/A"')
        created_at=$(echo "$pr_data" | jq -r '.createdAt // "N/A"')
        author=$(echo "$pr_data" | jq -r '.author.login // "N/A"')
        labels=$(echo "$pr_data" | jq -r '.labels[].name' // '')
        review_count=$(echo "$pr_data" | jq -r '.reviews | length // 0')
        comment_count=$(echo "$pr_data" | jq -r '.comments | length // 0')
    else
        # Use GitHub API
        pr_data=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/$REPO/pulls/$pr_num" 2>/dev/null || echo "")
        
        if [ -z "$pr_data" ] || echo "$pr_data" | jq -e '.message' &>/dev/null; then
            echo "  ⚠️  PR #$pr_num not found or not accessible"
            continue
        fi
        
        title=$(echo "$pr_data" | jq -r '.title // "N/A"')
        body=$(echo "$pr_data" | jq -r '.body // "N/A"')
        state=$(echo "$pr_data" | jq -r '.state // "N/A"')
        merged_at=$(echo "$pr_data" | jq -r '.merged_at // "N/A"')
        created_at=$(echo "$pr_data" | jq -r '.created_at // "N/A"')
        author=$(echo "$pr_data" | jq -r '.user.login // "N/A"')
        labels=$(echo "$pr_data" | jq -r '.labels[].name' | tr '\n' ',' | sed 's/,$//')
        review_count="N/A"
        comment_count="N/A"
    fi
    
    echo "" >> "$OUTPUT_DIR/pr-details-github.md"
    echo "## PR #$pr_num: $title" >> "$OUTPUT_DIR/pr-details-github.md"
    echo "" >> "$OUTPUT_DIR/pr-details-github.md"
    echo "- **State:** $state" >> "$OUTPUT_DIR/pr-details-github.md"
    echo "- **Author:** $author" >> "$OUTPUT_DIR/pr-details-github.md"
    echo "- **Created:** $created_at" >> "$OUTPUT_DIR/pr-details-github.md"
    if [ "$merged_at" != "N/A" ] && [ "$merged_at" != "null" ]; then
        echo "- **Merged:** $merged_at" >> "$OUTPUT_DIR/pr-details-github.md"
    fi
    if [ -n "$labels" ] && [ "$labels" != "" ]; then
        echo "- **Labels:** $labels" >> "$OUTPUT_DIR/pr-details-github.md"
    fi
    if [ "$review_count" != "N/A" ]; then
        echo "- **Reviews:** $review_count" >> "$OUTPUT_DIR/pr-details-github.md"
    fi
    if [ "$comment_count" != "N/A" ]; then
        echo "- **Comments:** $comment_count" >> "$OUTPUT_DIR/pr-details-github.md"
    fi
    echo "" >> "$OUTPUT_DIR/pr-details-github.md"
    
    if [ -n "$body" ] && [ "$body" != "N/A" ] && [ "$body" != "null" ]; then
        echo "### Description" >> "$OUTPUT_DIR/pr-details-github.md"
        echo "" >> "$OUTPUT_DIR/pr-details-github.md"
        echo "$body" >> "$OUTPUT_DIR/pr-details-github.md"
        echo "" >> "$OUTPUT_DIR/pr-details-github.md"
    fi
    
    echo "---" >> "$OUTPUT_DIR/pr-details-github.md"
    echo "" >> "$OUTPUT_DIR/pr-details-github.md"
done

echo ""
echo "PR details saved to: $OUTPUT_DIR/pr-details-github.md"

