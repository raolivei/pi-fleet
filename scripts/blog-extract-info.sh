#!/bin/bash
# Extract information from codebase to help populate the blog

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Eldertree Blog Information Extractor ==="
echo ""

# Function to extract hardware info
extract_hardware() {
    echo "## Hardware Information"
    echo ""
    grep -r "Raspberry Pi" "$PROJECT_ROOT/README.md" "$PROJECT_ROOT/pi-fleet/README.md" 2>/dev/null | head -5
    echo ""
    grep -r "8GB\|ARM64\|Debian" "$PROJECT_ROOT/README.md" "$PROJECT_ROOT/pi-fleet/README.md" 2>/dev/null | head -5
    echo ""
}

# Function to extract cluster info
extract_cluster() {
    echo "## Cluster Information"
    echo ""
    echo "### Control Plane"
    grep -r "eldertree\|192.168.2" "$PROJECT_ROOT/pi-fleet/README.md" "$PROJECT_ROOT/pi-fleet/NETWORK.md" 2>/dev/null | head -5
    echo ""
    echo "### Kubernetes Version"
    grep -r "K3s\|k3s\|v1\." "$PROJECT_ROOT/pi-fleet/README.md" "$PROJECT_ROOT/pi-fleet/CHANGELOG.md" 2>/dev/null | head -5
    echo ""
}

# Function to extract services
extract_services() {
    echo "## Deployed Services"
    echo ""
    echo "### Services from NETWORK.md:"
    grep -E "\.eldertree\.local" "$PROJECT_ROOT/pi-fleet/NETWORK.md" 2>/dev/null | head -10
    echo ""
    echo "### Services from README.md:"
    grep -E "https://.*\.eldertree\.local" "$PROJECT_ROOT/pi-fleet/README.md" 2>/dev/null | head -10
    echo ""
}

# Function to extract major milestones
extract_milestones() {
    echo "## Major Milestones"
    echo ""
    echo "### From CHANGELOG.md:"
    grep -E "^## \[|^### Added|^### Changed|^### Fixed" "$PROJECT_ROOT/pi-fleet/CHANGELOG.md" 2>/dev/null | head -20
    echo ""
    
    if [ -f "$PROJECT_ROOT/pi-fleet/DEPLOYMENT_SUMMARY_2025-11-17.md" ]; then
        echo "### From Deployment Summary:"
        grep -E "^###|^✅|^📊" "$PROJECT_ROOT/pi-fleet/DEPLOYMENT_SUMMARY_2025-11-17.md" 2>/dev/null | head -15
        echo ""
    fi
}

# Function to extract Vault info
extract_vault() {
    echo "## Vault Information"
    echo ""
    if [ -f "$PROJECT_ROOT/pi-fleet/VAULT.md" ]; then
        echo "### Vault Configuration:"
        grep -E "Version:|Mode:|Storage:" "$PROJECT_ROOT/pi-fleet/VAULT.md" 2>/dev/null | head -5
        echo ""
        echo "### Policies:"
        grep -E "policy|Policy" "$PROJECT_ROOT/pi-fleet/VAULT.md" 2>/dev/null | head -10
        echo ""
    fi
    
    if [ -f "$PROJECT_ROOT/pi-fleet/VAULT_DEPLOYMENT_SUCCESS.md" ]; then
        echo "### Deployment Date:"
        grep -E "Deployment Date|Last Updated" "$PROJECT_ROOT/pi-fleet/VAULT_DEPLOYMENT_SUCCESS.md" 2>/dev/null
        echo ""
    fi
}

# Function to extract troubleshooting info
extract_troubleshooting() {
    echo "## Troubleshooting Documentation"
    echo ""
    echo "### Available Troubleshooting Guides:"
    find "$PROJECT_ROOT/pi-fleet/docs" -name "*TROUBLESHOOT*" -o -name "*FIX*" -o -name "*RECOVERY*" 2>/dev/null | \
        sed 's|.*/||' | sort | head -15
    echo ""
}

# Function to extract network info
extract_network() {
    echo "## Network Configuration"
    echo ""
    if [ -f "$PROJECT_ROOT/pi-fleet/NETWORK.md" ]; then
        echo "### DNS Setup:"
        grep -A 5 "DNS\|Pi-hole" "$PROJECT_ROOT/pi-fleet/NETWORK.md" 2>/dev/null | head -10
        echo ""
        echo "### Service Domains:"
        grep -E "\.eldertree\.local" "$PROJECT_ROOT/pi-fleet/NETWORK.md" 2>/dev/null | head -10
        echo ""
    fi
}

# Function to extract tool versions
extract_versions() {
    echo "## Tool Versions"
    echo ""
    echo "From README.md and CHANGELOG.md:"
    grep -E "K3s|Helm|Vault|Prometheus|Grafana|Flux" "$PROJECT_ROOT/pi-fleet/README.md" "$PROJECT_ROOT/pi-fleet/CHANGELOG.md" 2>/dev/null | \
        grep -E "v[0-9]|Version" | head -10
    echo ""
}

# Function to extract git history
extract_git_history() {
    echo "## Git Commit History (Last 20 Commits)"
    echo ""
    if [ -d "$PROJECT_ROOT/pi-fleet/.git" ]; then
        cd "$PROJECT_ROOT/pi-fleet"
        git log --oneline --all -20 2>/dev/null || echo "Git history not available"
        echo ""
    else
        echo "Not a git repository or .git directory not found"
        echo ""
    fi
}

# Main menu
show_menu() {
    echo "What information would you like to extract?"
    echo ""
    echo "1) Hardware Information"
    echo "2) Cluster Information"
    echo "3) Deployed Services"
    echo "4) Major Milestones"
    echo "5) Vault Information"
    echo "6) Network Configuration"
    echo "7) Tool Versions"
    echo "8) Troubleshooting Documentation"
    echo "9) Git History"
    echo "10) All Information"
    echo "0) Exit"
    echo ""
    read -p "Enter choice [0-10]: " choice
    echo ""
}

# Process choice
process_choice() {
    case $choice in
        1) extract_hardware ;;
        2) extract_cluster ;;
        3) extract_services ;;
        4) extract_milestones ;;
        5) extract_vault ;;
        6) extract_network ;;
        7) extract_versions ;;
        8) extract_troubleshooting ;;
        9) extract_git_history ;;
        10)
            extract_hardware
            extract_cluster
            extract_services
            extract_milestones
            extract_vault
            extract_network
            extract_versions
            extract_troubleshooting
            extract_git_history
            ;;
        0) exit 0 ;;
        *) echo "Invalid choice" ;;
    esac
}

# Interactive mode
if [ "$1" = "--all" ]; then
    extract_hardware
    extract_cluster
    extract_services
    extract_milestones
    extract_vault
    extract_network
    extract_versions
    extract_troubleshooting
    extract_git_history
elif [ "$1" = "--hardware" ]; then
    extract_hardware
elif [ "$1" = "--cluster" ]; then
    extract_cluster
elif [ "$1" = "--services" ]; then
    extract_services
elif [ "$1" = "--milestones" ]; then
    extract_milestones
elif [ "$1" = "--vault" ]; then
    extract_vault
elif [ "$1" = "--network" ]; then
    extract_network
elif [ "$1" = "--versions" ]; then
    extract_versions
elif [ "$1" = "--troubleshooting" ]; then
    extract_troubleshooting
elif [ "$1" = "--git" ]; then
    extract_git_history
else
    # Interactive mode
    while true; do
        show_menu
        process_choice
        echo ""
        read -p "Press Enter to continue..."
        echo ""
    done
fi

