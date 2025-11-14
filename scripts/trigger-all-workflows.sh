#!/bin/bash

# Script to trigger all GitHub Actions workflows
# This script will trigger workflows that support workflow_dispatch
# For workflows without workflow_dispatch, it will create a dummy commit or PR

set -e

# Check if dry-run mode
DRY_RUN=${DRY_RUN:-false}
CREATE_COMMITS=${CREATE_COMMITS:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
info() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

# Function to get repository name from path
get_repo_name() {
    local path=$1
    local dir=$(basename "$path")
    echo "$dir"
}

# Function to get remote repository owner/repo
get_remote_repo() {
    local path=$1
    cd "$path" || return 1
    
    if [ ! -d ".git" ]; then
        return 1
    fi
    
    local remote=$(git remote get-url origin 2>/dev/null | sed -E 's|.*github.com[:/]([^/]+/[^/]+)\.git|\1|' | sed 's|\.git$||')
    echo "$remote"
}

# Function to get workflow name from YAML file
get_workflow_name() {
    local workflow_file=$1
    # Extract name from "name:" field, handling multi-line and quoted values
    grep -m 1 "^name:" "$workflow_file" | sed -E 's/^name:\s*["'\'']?([^"'\'']+)["'\'']?/\1/' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
}

# Function to trigger workflow_dispatch workflow
trigger_workflow() {
    local repo=$1
    local workflow_file=$2
    local workflow_name=$(get_workflow_name "$workflow_file")
    local workflow_file_name=$(basename "$workflow_file")
    
    if [ -z "$workflow_name" ]; then
        workflow_name=$(basename "$workflow_file" .yml | sed 's/\.yaml$//')
    fi
    
    info "Triggering workflow: $workflow_name in $repo"
    
    # Check if workflow needs inputs
    if grep -q "inputs:" "$workflow_file"; then
        warning "  Workflow requires inputs - skipping (use GitHub UI or gh CLI with inputs)"
        echo "    Example: gh workflow run \"$workflow_file_name\" --repo \"$repo\" --field <field>=<value>"
        return 1
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        info "  [DRY RUN] Would trigger: $workflow_name"
        return 0
    fi
    
    # Try triggering by workflow name first, then by filename, then by path
    local workflow_path=".github/workflows/$workflow_file_name"
    if gh workflow run "$workflow_name" --repo "$repo" 2>/dev/null || \
       gh workflow run "$workflow_file_name" --repo "$repo" 2>/dev/null || \
       gh workflow run "$workflow_path" --repo "$repo" 2>/dev/null; then
        success "  Triggered: $workflow_name"
        return 0
    else
        # Try to get workflow ID and use that
        local workflow_id=$(gh workflow list --repo "$repo" --json name,id 2>/dev/null | \
            jq -r ".[] | select(.name == \"$workflow_name\") | .id" 2>/dev/null)
        if [ -n "$workflow_id" ] && [ "$workflow_id" != "null" ]; then
            if gh api "repos/$repo/actions/workflows/$workflow_id/dispatches" \
                -X POST -f ref="$(gh repo view "$repo" --json defaultBranchRef -q .defaultBranchRef.name)" 2>/dev/null; then
                success "  Triggered: $workflow_name (via API)"
                return 0
            fi
        fi
        error "  Failed to trigger: $workflow_name"
        info "    Tried: name='$workflow_name', file='$workflow_file_name', path='$workflow_path'"
        return 1
    fi
}

# Function to create dummy commit to trigger workflow
trigger_via_commit() {
    local path=$1
    local repo=$2
    local branch=${3:-main}
    
    cd "$path" || return 1
    
    if [ ! -d ".git" ]; then
        warning "  Not a git repository - skipping"
        return 1
    fi
    
    if [ "$CREATE_COMMITS" != "true" ]; then
        warning "  Would create commit to trigger (set CREATE_COMMITS=true to enable)"
        return 1
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        info "  [DRY RUN] Would create commit to trigger workflow"
        return 0
    fi
    
    # Check if we're on the right branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "")
    if [ -z "$current_branch" ]; then
        warning "  No git branch found - skipping"
        return 1
    fi
    
    # Create a dummy commit
    info "  Creating dummy commit to trigger workflow..."
    
    # Create or update a trigger file
    echo "# Workflow trigger - $(date)" >> .workflow-trigger 2>/dev/null || true
    git add .workflow-trigger 2>/dev/null || true
    
    # Try to commit
    if git commit -m "chore: trigger workflow [skip ci]" --allow-empty 2>/dev/null; then
        if git push origin "$current_branch" 2>/dev/null; then
            success "  Pushed dummy commit to trigger workflow"
            return 0
        else
            warning "  Commit created but push failed (may need to push manually)"
            return 1
        fi
    else
        warning "  No changes to commit or commit failed"
        return 1
    fi
}

# Main execution
main() {
    info "GitHub Actions Workflow Trigger Script"
    info "====================================="
    echo ""
    
    # Find all workflow files
    local workflows_dir="/Users/roliveira/WORKSPACE/raolivei"
    local triggered=0
    local skipped=0
    local failed=0
    
    # Process each repository
    for repo_path in "$workflows_dir"/*/; do
        if [ ! -d "$repo_path/.github/workflows" ]; then
            continue
        fi
        
        local repo_name=$(get_repo_name "$repo_path")
        local remote_repo=$(get_remote_repo "$repo_path")
        
        if [ -z "$remote_repo" ]; then
            warning "Skipping $repo_name (no remote repository found)"
            continue
        fi
        
        info "Processing repository: $repo_name ($remote_repo)"
        
        # Find all workflow files
        for workflow_file in "$repo_path"/.github/workflows/*.yml "$repo_path"/.github/workflows/*.yaml; do
            if [ ! -f "$workflow_file" ]; then
                continue
            fi
            
            local workflow_name=$(basename "$workflow_file")
            
            # Check if workflow has workflow_dispatch
            if grep -q "workflow_dispatch:" "$workflow_file"; then
                if trigger_workflow "$remote_repo" "$workflow_file"; then
                    ((triggered++))
                else
                    ((skipped++))
                fi
            else
                # Check what triggers the workflow
                if grep -q "pull_request:" "$workflow_file"; then
                    warning "  $workflow_name: Requires PR - skipping (create PR manually)"
                    ((skipped++))
                elif grep -q "push:" "$workflow_file"; then
                    info "  $workflow_name: Triggering via commit..."
                    if trigger_via_commit "$repo_path" "$remote_repo"; then
                        ((triggered++))
                    else
                        ((failed++))
                    fi
                elif grep -q "schedule:" "$workflow_file"; then
                    warning "  $workflow_name: Scheduled workflow - will run automatically"
                    ((skipped++))
                else
                    warning "  $workflow_name: Unknown trigger - skipping"
                    ((skipped++))
                fi
            fi
        done
        
        echo ""
    done
    
    # Summary
    echo ""
    info "Summary:"
    success "  Triggered: $triggered workflows"
    warning "  Skipped: $skipped workflows"
    if [ $failed -gt 0 ]; then
        error "  Failed: $failed workflows"
    fi
    
    echo ""
    info "Notes:"
    info "  - Workflows that require inputs need to be triggered manually"
    info "  - Use dry-run mode: DRY_RUN=true ./trigger-all-workflows.sh"
    info "  - Enable commit creation: CREATE_COMMITS=true ./trigger-all-workflows.sh"
    info ""
    info "To trigger workflows with inputs manually:"
    info "  gh workflow run <workflow.yml> --repo <owner/repo> --field <field>=<value>"
    info ""
    info "Example for terraform-pr-apply:"
    info "  gh workflow run terraform-pr-apply.yml --repo raolivei/us-law-severity-map --field pr_number=123"
}

# Run main function
main

