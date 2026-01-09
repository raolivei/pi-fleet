#!/usr/bin/env bash
# Analyze Git commit history and PRs to extract journey, problems, and decisions
# Requires bash 4+ for associative arrays

set -e

# Use Homebrew bash if available (macOS default bash is too old)
if [ -f "/opt/homebrew/bin/bash" ]; then
    # This will be handled by the shebang, but we check here too
    :
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/blog-analysis"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

mkdir -p "$OUTPUT_DIR"

cd "$PROJECT_ROOT"

echo -e "${BLUE}=== Eldertree Git History Analysis ===${NC}"
echo ""

# Function to extract PR number from commit message
extract_pr_number() {
    echo "$1" | grep -oE '#[0-9]+' | head -1 | sed 's/#//'
}

# Function to categorize commit type
categorize_commit() {
    local msg="$1"
    case "$msg" in
        feat:*|feat\(*) echo "feature" ;;
        fix:*|fix\(*|Fix:*) echo "bugfix" ;;
        refactor:*|refactor\(*) echo "refactor" ;;
        chore:*|chore\(*) echo "maintenance" ;;
        docs:*|docs\(*) echo "documentation" ;;
        test:*|test\(*) echo "testing" ;;
        *) echo "other" ;;
    esac
}

# Function to extract problems from commit messages
extract_problems() {
    local msg="$1"
    local body="$2"
    
    # Look for problem indicators
    if echo "$msg $body" | grep -qiE "fix|broken|issue|problem|error|bug|crash|fail"; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to extract solutions from commit messages
extract_solution() {
    local body="$1"
    if [ -n "$body" ] && [ "$body" != "-" ]; then
        echo "$body" | head -5
    else
        echo "See commit diff for details"
    fi
}

# 1. Generate comprehensive commit timeline
echo -e "${GREEN}1. Generating commit timeline...${NC}"
git log --format="%H|%ai|%an|%s|%b" --all --reverse > "$OUTPUT_DIR/commits-raw.txt"

# Process commits into structured format
cat > "$OUTPUT_DIR/commits-timeline.md" << 'EOF'
# Git Commit Timeline - Eldertree Journey

This document shows the chronological evolution of the eldertree cluster based on Git commit history.

EOF

echo "## Commit Statistics" >> "$OUTPUT_DIR/commits-timeline.md"
echo "" >> "$OUTPUT_DIR/commits-timeline.md"
TOTAL_COMMITS=$(git rev-list --all --count)
echo "- **Total Commits:** $TOTAL_COMMITS" >> "$OUTPUT_DIR/commits-timeline.md"
echo "- **Analysis Date:** $(date +"%Y-%m-%d %H:%M:%S")" >> "$OUTPUT_DIR/commits-timeline.md"
echo "" >> "$OUTPUT_DIR/commits-timeline.md"

# 2. Extract commits by category
echo -e "${GREEN}2. Categorizing commits...${NC}"

declare -A categories
declare -A prs

while IFS='|' read -r hash date author subject body; do
    category=$(categorize_commit "$subject")
    categories["$category"]=$((${categories["$category"]:-0} + 1))
    
    pr_num=$(extract_pr_number "$subject $body")
    if [ -n "$pr_num" ]; then
        prs["$pr_num"]=$((${prs["$pr_num"]:-0} + 1))
    fi
done < "$OUTPUT_DIR/commits-raw.txt"

echo "## Commits by Category" >> "$OUTPUT_DIR/commits-timeline.md"
echo "" >> "$OUTPUT_DIR/commits-timeline.md"
for category in "${!categories[@]}"; do
    echo "- **$category:** ${categories[$category]}" >> "$OUTPUT_DIR/commits-timeline.md"
done
echo "" >> "$OUTPUT_DIR/commits-timeline.md"

echo "## Pull Requests Found" >> "$OUTPUT_DIR/commits-timeline.md"
echo "" >> "$OUTPUT_DIR/commits-timeline.md"
for pr in "${!prs[@]}"; do
    echo "- PR #$pr (${prs[$pr]} commits)" >> "$OUTPUT_DIR/commits-timeline.md"
done
echo "" >> "$OUTPUT_DIR/commits-timeline.md"

# 3. Generate detailed timeline
echo -e "${GREEN}3. Generating detailed timeline...${NC}"
echo "" >> "$OUTPUT_DIR/commits-timeline.md"
echo "## Detailed Timeline" >> "$OUTPUT_DIR/commits-timeline.md"
echo "" >> "$OUTPUT_DIR/commits-timeline.md"

current_date=""
while IFS='|' read -r hash date author subject body; do
    commit_date=$(echo "$date" | cut -d' ' -f1)
    
    # Group by date
    if [ "$commit_date" != "$current_date" ]; then
        if [ -n "$current_date" ]; then
            echo "" >> "$OUTPUT_DIR/commits-timeline.md"
        fi
        echo "### $commit_date" >> "$OUTPUT_DIR/commits-timeline.md"
        echo "" >> "$OUTPUT_DIR/commits-timeline.md"
        current_date="$commit_date"
    fi
    
    category=$(categorize_commit "$subject")
    pr_num=$(extract_pr_number "$subject $body")
    has_problem=$(extract_problems "$subject" "$body")
    
    echo "#### \`$hash\` - $subject" >> "$OUTPUT_DIR/commits-timeline.md"
    echo "" >> "$OUTPUT_DIR/commits-timeline.md"
    echo "- **Type:** $category" >> "$OUTPUT_DIR/commits-timeline.md"
    echo "- **Author:** $author" >> "$OUTPUT_DIR/commits-timeline.md"
    if [ -n "$pr_num" ]; then
        echo "- **PR:** #$pr_num" >> "$OUTPUT_DIR/commits-timeline.md"
    fi
    if [ "$has_problem" = "true" ]; then
        echo "- **Problem Identified:** Yes" >> "$OUTPUT_DIR/commits-timeline.md"
    fi
    echo "" >> "$OUTPUT_DIR/commits-timeline.md"
    
    if [ -n "$body" ] && [ "$body" != "-" ]; then
        echo "**Details:**" >> "$OUTPUT_DIR/commits-timeline.md"
        echo '```' >> "$OUTPUT_DIR/commits-timeline.md"
        echo "$body" | head -10 >> "$OUTPUT_DIR/commits-timeline.md"
        echo '```' >> "$OUTPUT_DIR/commits-timeline.md"
        echo "" >> "$OUTPUT_DIR/commits-timeline.md"
    fi
    
    echo "---" >> "$OUTPUT_DIR/commits-timeline.md"
    echo "" >> "$OUTPUT_DIR/commits-timeline.md"
done < "$OUTPUT_DIR/commits-raw.txt"

# 4. Extract problems and solutions
echo -e "${GREEN}4. Extracting problems and solutions...${NC}"
cat > "$OUTPUT_DIR/problems-and-solutions.md" << 'EOF'
# Problems and Solutions - Eldertree Journey

This document extracts problems encountered and solutions implemented based on commit history.

EOF

problem_count=0
while IFS='|' read -r hash date author subject body; do
    has_problem=$(extract_problems "$subject" "$body")
    
    if [ "$has_problem" = "true" ]; then
        problem_count=$((problem_count + 1))
        commit_date=$(echo "$date" | cut -d' ' -f1)
        category=$(categorize_commit "$subject")
        pr_num=$(extract_pr_number "$subject $body")
        
        echo "## Problem #$problem_count: $subject" >> "$OUTPUT_DIR/problems-and-solutions.md"
        echo "" >> "$OUTPUT_DIR/problems-and-solutions.md"
        echo "- **Date:** $commit_date" >> "$OUTPUT_DIR/problems-and-solutions.md"
        echo "- **Commit:** \`$hash\`" >> "$OUTPUT_DIR/problems-and-solutions.md"
        echo "- **Category:** $category" >> "$OUTPUT_DIR/problems-and-solutions.md"
        if [ -n "$pr_num" ]; then
            echo "- **PR:** #$pr_num" >> "$OUTPUT_DIR/problems-and-solutions.md"
        fi
        echo "" >> "$OUTPUT_DIR/problems-and-solutions.md"
        
        # Extract problem description
        if echo "$subject $body" | grep -qiE "fix|broken|issue|problem|error|bug"; then
            echo "### Problem Description" >> "$OUTPUT_DIR/problems-and-solutions.md"
            echo "" >> "$OUTPUT_DIR/problems-and-solutions.md"
            echo "$subject" >> "$OUTPUT_DIR/problems-and-solutions.md"
            echo "" >> "$OUTPUT_DIR/problems-and-solutions.md"
        fi
        
        # Extract solution
        if [ -n "$body" ] && [ "$body" != "-" ]; then
            echo "### Solution" >> "$OUTPUT_DIR/problems-and-solutions.md"
            echo "" >> "$OUTPUT_DIR/problems-and-solutions.md"
            echo '```' >> "$OUTPUT_DIR/problems-and-solutions.md"
            echo "$body" | head -15 >> "$OUTPUT_DIR/problems-and-solutions.md"
            echo '```' >> "$OUTPUT_DIR/problems-and-solutions.md"
            echo "" >> "$OUTPUT_DIR/problems-and-solutions.md"
        fi
        
        echo "---" >> "$OUTPUT_DIR/problems-and-solutions.md"
        echo "" >> "$OUTPUT_DIR/problems-and-solutions.md"
    fi
done < "$OUTPUT_DIR/commits-raw.txt"

echo "- **Total Problems Identified:** $problem_count" >> "$OUTPUT_DIR/problems-and-solutions.md"
sed -i '' "1a\\
\\
**Total Problems Identified:** $problem_count\\
\\
" "$OUTPUT_DIR/problems-and-solutions.md" 2>/dev/null || \
sed -i "1a\\
\\
**Total Problems Identified:** $problem_count\\
\\
" "$OUTPUT_DIR/problems-and-solutions.md"

# 5. Extract major decisions (features)
echo -e "${GREEN}5. Extracting major features and decisions...${NC}"
cat > "$OUTPUT_DIR/features-and-decisions.md" << 'EOF'
# Features and Decisions - Eldertree Journey

This document tracks major features added and architectural decisions made.

EOF

feature_count=0
while IFS='|' read -r hash date author subject body; do
    category=$(categorize_commit "$subject")
    
    if [ "$category" = "feature" ] || echo "$subject" | grep -qiE "add|implement|create|setup|deploy|enable"; then
        feature_count=$((feature_count + 1))
        commit_date=$(echo "$date" | cut -d' ' -f1)
        pr_num=$(extract_pr_number "$subject $body")
        
        echo "## Feature/Decision #$feature_count: $subject" >> "$OUTPUT_DIR/features-and-decisions.md"
        echo "" >> "$OUTPUT_DIR/features-and-decisions.md"
        echo "- **Date:** $commit_date" >> "$OUTPUT_DIR/features-and-decisions.md"
        echo "- **Commit:** \`$hash\`" >> "$OUTPUT_DIR/features-and-decisions.md"
        if [ -n "$pr_num" ]; then
            echo "- **PR:** #$pr_num" >> "$OUTPUT_DIR/features-and-decisions.md"
        fi
        echo "" >> "$OUTPUT_DIR/features-and-decisions.md"
        
        if [ -n "$body" ] && [ "$body" != "-" ]; then
            echo "### Details" >> "$OUTPUT_DIR/features-and-decisions.md"
            echo "" >> "$OUTPUT_DIR/features-and-decisions.md"
            echo "$body" | head -15 >> "$OUTPUT_DIR/features-and-decisions.md"
            echo "" >> "$OUTPUT_DIR/features-and-decisions.md"
        fi
        
        echo "---" >> "$OUTPUT_DIR/features-and-decisions.md"
        echo "" >> "$OUTPUT_DIR/features-and-decisions.md"
    fi
done < "$OUTPUT_DIR/commits-raw.txt"

# 6. Generate PR summary
echo -e "${GREEN}6. Generating PR summary...${NC}"
cat > "$OUTPUT_DIR/pr-summary.md" << 'EOF'
# Pull Request Summary - Eldertree Journey

This document summarizes all Pull Requests found in the commit history.

EOF

declare -A pr_details

# Collect PR information
while IFS='|' read -r hash date author subject body; do
    pr_num=$(extract_pr_number "$subject $body")
    if [ -n "$pr_num" ]; then
        if [ -z "${pr_details[$pr_num]}" ]; then
            pr_details["$pr_num"]="$hash|$date|$subject|$body"
        fi
    fi
done < "$OUTPUT_DIR/commits-raw.txt"

echo "## Pull Requests Found: ${#pr_details[@]}" >> "$OUTPUT_DIR/pr-summary.md"
echo "" >> "$OUTPUT_DIR/pr-summary.md"

for pr_num in $(printf '%s\n' "${!pr_details[@]}" | sort -n); do
    IFS='|' read -r hash date subject body <<< "${pr_details[$pr_num]}"
    commit_date=$(echo "$date" | cut -d' ' -f1)
    
    echo "## PR #$pr_num" >> "$OUTPUT_DIR/pr-summary.md"
    echo "" >> "$OUTPUT_DIR/pr-summary.md"
    echo "- **Title:** $subject" >> "$OUTPUT_DIR/pr-summary.md"
    echo "- **Date:** $commit_date" >> "$OUTPUT_DIR/pr-summary.md"
    echo "- **Merge Commit:** \`$hash\`" >> "$OUTPUT_DIR/pr-summary.md"
    echo "" >> "$OUTPUT_DIR/pr-summary.md"
    
    if [ -n "$body" ] && [ "$body" != "-" ]; then
        echo "### Description" >> "$OUTPUT_DIR/pr-summary.md"
        echo "" >> "$OUTPUT_DIR/pr-summary.md"
        echo "$body" | head -20 >> "$OUTPUT_DIR/pr-summary.md"
        echo "" >> "$OUTPUT_DIR/pr-summary.md"
    fi
    
    echo "### Related Commits" >> "$OUTPUT_DIR/pr-summary.md"
    echo "" >> "$OUTPUT_DIR/pr-summary.md"
    git log --format="- \`%h\` %s" --grep="#$pr_num" --all >> "$OUTPUT_DIR/pr-summary.md" 2>/dev/null || echo "- No additional commits found" >> "$OUTPUT_DIR/pr-summary.md"
    echo "" >> "$OUTPUT_DIR/pr-summary.md"
    echo "---" >> "$OUTPUT_DIR/pr-summary.md"
    echo "" >> "$OUTPUT_DIR/pr-summary.md"
done

# 7. Generate blog-ready narrative
echo -e "${GREEN}7. Generating blog-ready narrative...${NC}"
cat > "$OUTPUT_DIR/blog-narrative.md" << 'EOF'
# Eldertree Journey - Narrative from Git History

This document provides a narrative-style summary of the eldertree cluster journey based on Git commit history, suitable for blog chapters.

EOF

# Group commits by month for narrative
echo "## Journey Overview" >> "$OUTPUT_DIR/blog-narrative.md"
echo "" >> "$OUTPUT_DIR/blog-narrative.md"

current_month=""
month_count=0

while IFS='|' read -r hash date author subject body; do
    commit_date=$(echo "$date" | cut -d' ' -f1)
    month=$(echo "$commit_date" | cut -d'-' -f1,2)
    
    if [ "$month" != "$current_month" ]; then
        if [ -n "$current_month" ]; then
            echo "" >> "$OUTPUT_DIR/blog-narrative.md"
        fi
        month_count=$((month_count + 1))
        echo "### Month $month_count: $month" >> "$OUTPUT_DIR/blog-narrative.md"
        echo "" >> "$OUTPUT_DIR/blog-narrative.md"
        current_month="$month"
    fi
    
    category=$(categorize_commit "$subject")
    pr_num=$(extract_pr_number "$subject $body")
    has_problem=$(extract_problems "$subject" "$body")
    
    # Write narrative-style entry
    if [ "$category" = "feature" ]; then
        echo "**Feature Added:** $subject" >> "$OUTPUT_DIR/blog-narrative.md"
    elif [ "$has_problem" = "true" ]; then
        echo "**Issue Resolved:** $subject" >> "$OUTPUT_DIR/blog-narrative.md"
    else
        echo "**Change:** $subject" >> "$OUTPUT_DIR/blog-narrative.md"
    fi
    
    if [ -n "$pr_num" ]; then
        echo "  - *Resolved via PR #$pr_num*" >> "$OUTPUT_DIR/blog-narrative.md"
    fi
    
    if [ -n "$body" ] && [ "$body" != "-" ] && [ ${#body} -lt 200 ]; then
        echo "  - $body" | head -1 >> "$OUTPUT_DIR/blog-narrative.md"
    fi
    
    echo "" >> "$OUTPUT_DIR/blog-narrative.md"
done < "$OUTPUT_DIR/commits-raw.txt"

# 8. Generate summary statistics
echo -e "${GREEN}8. Generating summary statistics...${NC}"
cat > "$OUTPUT_DIR/summary-statistics.md" << 'EOF'
# Summary Statistics - Eldertree Git History

EOF

echo "## Overall Statistics" >> "$OUTPUT_DIR/summary-statistics.md"
echo "" >> "$OUTPUT_DIR/summary-statistics.md"
echo "- **Total Commits:** $TOTAL_COMMITS" >> "$OUTPUT_DIR/summary-statistics.md"
echo "- **Pull Requests:** ${#pr_details[@]}" >> "$OUTPUT_DIR/summary-statistics.md"
echo "- **Problems Identified:** $problem_count" >> "$OUTPUT_DIR/summary-statistics.md"
echo "- **Features Added:** $feature_count" >> "$OUTPUT_DIR/summary-statistics.md"
echo "" >> "$OUTPUT_DIR/summary-statistics.md"

echo "## Commits by Category" >> "$OUTPUT_DIR/summary-statistics.md"
echo "" >> "$OUTPUT_DIR/summary-statistics.md"
for category in "${!categories[@]}"; do
    percentage=$(echo "scale=1; ${categories[$category]} * 100 / $TOTAL_COMMITS" | bc)
    echo "- **$category:** ${categories[$category]} ($percentage%)" >> "$OUTPUT_DIR/summary-statistics.md"
done

# Final output
echo ""
echo -e "${GREEN}=== Analysis Complete ===${NC}"
echo ""
echo "Generated files in: $OUTPUT_DIR"
echo ""
echo "Files created:"
echo "  - commits-timeline.md - Detailed chronological timeline"
echo "  - problems-and-solutions.md - Extracted problems and fixes"
echo "  - features-and-decisions.md - Major features and decisions"
echo "  - pr-summary.md - Pull request summary"
echo "  - blog-narrative.md - Blog-ready narrative"
echo "  - summary-statistics.md - Overall statistics"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review the generated files"
echo "  2. Use them to populate your blog chapters"
echo "  3. Add personal context and lessons learned"
echo "  4. Enhance with additional details from your memory"
echo ""

