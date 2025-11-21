#!/bin/bash
set -e

# Complete setup script for eldertree Raspberry Pi cluster
# This script automates the entire post-OS-installation setup process

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Eldertree Cluster Setup ==="
echo "This script will:"
echo "  1. Configure system settings (Ansible)"
echo "  2. Install k3s cluster (Terraform)"
echo "  3. Bootstrap FluxCD GitOps"
echo "  4. Verify installation"
echo "===========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}[1/5] Checking prerequisites...${NC}"

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}❌ $1 not found${NC}"
        echo -e "${YELLOW}   Install with: $2${NC}"
        exit 1
    fi
}

check_command "ansible" "brew install ansible"
check_command "terraform" "brew install terraform"
check_command "kubectl" "brew install kubectl"
check_command "sshpass" "brew install hudochenkov/sshpass/sshpass"
check_command "flux" "brew install fluxcd/tap/flux"

echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo ""

# Get Pi IP address
echo -e "${YELLOW}[2/5] Pi Configuration${NC}"
read -p "Enter Raspberry Pi IP address (or hostname): " PI_IP
read -p "Enter SSH username [pi]: " PI_USER
PI_USER=${PI_USER:-pi}

echo ""
echo -e "${BLUE}Pi Configuration:${NC}"
echo "  IP/Hostname: ${PI_IP}"
echo "  User: ${PI_USER}"
echo ""

# Update Ansible inventory
echo -e "${YELLOW}[3/5] Updating Ansible inventory...${NC}"
INVENTORY_FILE="${ANSIBLE_DIR}/inventory/hosts.yml"

# Backup inventory
cp "${INVENTORY_FILE}" "${INVENTORY_FILE}.backup.$(date +%Y%m%d-%H%M%S)"

# Update inventory with Pi IP
cat > "${INVENTORY_FILE}" <<EOF
---
all:
  children:
    raspberry_pi:
      hosts:
        eldertree:
          ansible_host: ${PI_IP}
          ansible_user: ${PI_USER}
          ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
EOF

echo -e "${GREEN}✓ Inventory updated${NC}"
echo ""

# Run Ansible playbook
echo -e "${YELLOW}[4/5] Running Ansible system setup...${NC}"
cd "${ANSIBLE_DIR}"

ansible-playbook playbooks/setup-system.yml \
  --ask-pass \
  --ask-become-pass \
  || {
    echo -e "${RED}❌ Ansible playbook failed${NC}"
    exit 1
  }

echo -e "${GREEN}✓ System configuration complete${NC}"
echo ""

# Update Terraform variables
echo -e "${YELLOW}[5/5] Configuring Terraform...${NC}"
cd "${TERRAFORM_DIR}"

if [ ! -f terraform.tfvars ]; then
    if [ -f terraform.tfvars.example ]; then
        cp terraform.tfvars.example terraform.tfvars
        echo -e "${YELLOW}  Created terraform.tfvars from example${NC}"
        echo -e "${YELLOW}  Please edit terraform.tfvars with your settings${NC}"
        echo ""
        read -p "Press Enter after editing terraform.tfvars..."
    else
        echo -e "${RED}❌ terraform.tfvars.example not found${NC}"
        exit 1
    fi
fi

# Initialize Terraform
echo -e "${BLUE}  Initializing Terraform...${NC}"
terraform init || {
    echo -e "${RED}❌ Terraform init failed${NC}"
    exit 1
}

# Apply Terraform
echo -e "${BLUE}  Applying Terraform configuration...${NC}"
echo -e "${YELLOW}  This will install k3s - it may take several minutes...${NC}"
terraform apply || {
    echo -e "${RED}❌ Terraform apply failed${NC}"
    exit 1
}

echo -e "${GREEN}✓ k3s installation complete${NC}"
echo ""

# Verify kubeconfig
KUBECONFIG_PATH="${HOME}/.kube/config-eldertree"
if [ -f "${KUBECONFIG_PATH}" ]; then
    export KUBECONFIG="${KUBECONFIG_PATH}"
    echo -e "${BLUE}  Verifying cluster...${NC}"
    kubectl get nodes || {
        echo -e "${YELLOW}  ⚠️  Cluster not ready yet, waiting...${NC}"
        sleep 10
        kubectl get nodes || {
            echo -e "${RED}❌ Cluster verification failed${NC}"
            exit 1
        }
    }
    echo -e "${GREEN}✓ Cluster is ready${NC}"
else
    echo -e "${YELLOW}  ⚠️  Kubeconfig not found at ${KUBECONFIG_PATH}${NC}"
fi

echo ""

# Bootstrap FluxCD
echo -e "${YELLOW}[6/6] Bootstrap FluxCD GitOps? (y/n)${NC}"
read -p "> " BOOTSTRAP_FLUX

if [ "${BOOTSTRAP_FLUX}" = "y" ] || [ "${BOOTSTRAP_FLUX}" = "Y" ]; then
    echo -e "${BLUE}  Bootstrapping FluxCD...${NC}"
    
    export KUBECONFIG="${KUBECONFIG_PATH}"
    
    flux bootstrap github \
      --owner=raolivei \
      --repository=raolivei \
      --branch=main \
      --path=clusters/eldertree \
      --personal \
      || {
        echo -e "${YELLOW}  ⚠️  Flux bootstrap failed (may need GitHub token)${NC}"
        echo -e "${YELLOW}  You can bootstrap manually later with:${NC}"
        echo -e "${BLUE}    flux bootstrap github --owner=raolivei --repository=raolivei --branch=main --path=clusters/eldertree --personal${NC}"
      }
    
    echo -e "${GREEN}✓ FluxCD bootstrap complete${NC}"
else
    echo -e "${YELLOW}  Skipping FluxCD bootstrap${NC}"
    echo -e "${YELLOW}  Bootstrap manually later with:${NC}"
    echo -e "${BLUE}    export KUBECONFIG=~/.kube/config-eldertree${NC}"
    echo -e "${BLUE}    flux bootstrap github --owner=raolivei --repository=raolivei --branch=main --path=clusters/eldertree --personal${NC}"
fi

echo ""
echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Verify cluster: kubectl get nodes -A"
echo "  2. Check FluxCD: flux get all"
echo "  3. Monitor deployments: kubectl get pods -A -w"
echo "  4. Restore Vault secrets (if needed)"
echo ""
echo "Useful commands:"
echo "  export KUBECONFIG=~/.kube/config-eldertree"
echo "  kubectl get pods -A"
echo "  flux get all"
echo ""

