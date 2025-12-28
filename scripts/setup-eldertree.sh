#!/bin/bash
set -e

# Complete setup script for eldertree Raspberry Pi cluster
# This script automates the entire post-OS-installation setup process
# Uses Ansible for system configuration, k3s installation, and operational tasks

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"
KUBECONFIG_PATH="${HOME}/.kube/config-eldertree"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Eldertree Cluster Setup ==="
echo "This script will:"
echo "  1. Configure system settings (Ansible)"
echo "  2. Install k3s cluster (Ansible)"
echo "  3. Bootstrap FluxCD GitOps (Ansible, optional)"
echo "  4. Verify installation"
echo "===========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}[1/6] Checking prerequisites...${NC}"

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}❌ $1 not found${NC}"
        echo -e "${YELLOW}   Install with: $2${NC}"
        exit 1
    fi
}

check_command "ansible" "brew install ansible"
# Terraform is optional (only needed for Cloudflare resources)
# check_command "terraform" "brew install terraform"
check_command "kubectl" "brew install kubectl"
check_command "sshpass" "brew install hudochenkov/sshpass/sshpass"
check_command "flux" "brew install fluxcd/tap/flux"

echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo ""

# Get Pi IP address
echo -e "${YELLOW}[2/6] Pi Configuration${NC}"
read -p "Enter Raspberry Pi IP address (or hostname): " PI_IP
read -p "Enter SSH username [pi]: " PI_USER
PI_USER=${PI_USER:-pi}

echo ""
echo -e "${BLUE}Pi Configuration:${NC}"
echo "  IP/Hostname: ${PI_IP}"
echo "  User: ${PI_USER}"
echo ""

# Update Ansible inventory
echo -e "${YELLOW}[3/6] Updating Ansible inventory...${NC}"
INVENTORY_FILE="${ANSIBLE_DIR}/inventory/hosts.yml"

# Backup inventory
if [ -f "${INVENTORY_FILE}" ]; then
    cp "${INVENTORY_FILE}" "${INVENTORY_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
fi

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

# Run Ansible system setup playbook
echo -e "${YELLOW}[4/6] Running Ansible system setup...${NC}"
cd "${ANSIBLE_DIR}"

ansible-playbook playbooks/setup-system.yml \
  --ask-pass \
  --ask-become-pass \
  || {
    echo -e "${RED}❌ Ansible system setup failed${NC}"
    echo -e "${YELLOW}  Troubleshooting:${NC}"
    echo -e "${BLUE}    - Verify SSH connectivity: ssh ${PI_USER}@${PI_IP}${NC}"
    echo -e "${BLUE}    - Check Ansible verbose output: ansible-playbook playbooks/setup-system.yml -vvv${NC}"
    exit 1
  }

echo -e "${GREEN}✓ System configuration complete${NC}"
echo ""

# Check if k3s is already installed (idempotency check)
echo -e "${YELLOW}[5/6] Checking k3s installation status...${NC}"
K3S_INSTALLED=false

if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${PI_USER}@${PI_IP}" "sudo systemctl is-active --quiet k3s" 2>/dev/null; then
    K3S_INSTALLED=true
    echo -e "${GREEN}✓ k3s is already installed${NC}"
    
    # Check if kubeconfig exists locally
    if [ -f "${KUBECONFIG_PATH}" ]; then
        echo -e "${GREEN}✓ Kubeconfig found at ${KUBECONFIG_PATH}${NC}"
        export KUBECONFIG="${KUBECONFIG_PATH}"
        
        # Verify cluster is accessible
        if kubectl get nodes &>/dev/null; then
            echo -e "${GREEN}✓ Cluster is accessible${NC}"
        else
            echo -e "${YELLOW}  ⚠️  Cluster not accessible, will re-run k3s installation${NC}"
            K3S_INSTALLED=false
        fi
    else
        echo -e "${YELLOW}  ⚠️  Kubeconfig not found locally, will re-run k3s installation to retrieve it${NC}"
        K3S_INSTALLED=false
    fi
else
    echo -e "${BLUE}  k3s not installed, proceeding with Ansible...${NC}"
fi

echo ""

# Install k3s with Ansible if needed
if [ "${K3S_INSTALLED}" = false ]; then
    echo -e "${YELLOW}[5/6] Installing k3s with Ansible...${NC}"
    cd "${ANSIBLE_DIR}"
    
    ansible-playbook playbooks/install-k3s.yml \
      --ask-pass \
      --ask-become-pass \
      || {
        echo -e "${RED}❌ k3s installation failed${NC}"
        echo -e "${YELLOW}  Troubleshooting:${NC}"
        echo -e "${BLUE}    - Check SSH connectivity: ssh ${PI_USER}@${PI_IP}${NC}"
        echo -e "${BLUE}    - Verify Ansible verbose output: ansible-playbook playbooks/install-k3s.yml -vvv${NC}"
        echo -e "${BLUE}    - Check if Pi needs reboot for cgroup configuration${NC}"
        exit 1
      }
    
    echo -e "${GREEN}✓ k3s installation complete${NC}"
    echo ""
fi

# Verify kubeconfig and cluster
echo -e "${YELLOW}[6/6] Verifying cluster...${NC}"
if [ -f "${KUBECONFIG_PATH}" ]; then
    export KUBECONFIG="${KUBECONFIG_PATH}"
    echo -e "${BLUE}  Verifying cluster connectivity...${NC}"
    
    # Wait for cluster to be ready with retries
    MAX_RETRIES=12
    RETRY_COUNT=0
    CLUSTER_READY=false
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if kubectl get nodes &>/dev/null; then
            CLUSTER_READY=true
            break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo -e "${YELLOW}  Waiting for cluster... (${RETRY_COUNT}/${MAX_RETRIES})${NC}"
        sleep 5
    done
    
    if [ "${CLUSTER_READY}" = true ]; then
        echo -e "${GREEN}✓ Cluster is ready${NC}"
        kubectl get nodes
    else
        echo -e "${RED}❌ Cluster verification failed after ${MAX_RETRIES} attempts${NC}"
        echo -e "${YELLOW}  Troubleshooting:${NC}"
        echo -e "${BLUE}    - Check k3s service: ssh ${PI_USER}@${PI_IP} 'sudo systemctl status k3s'${NC}"
        echo -e "${BLUE}    - Check k3s logs: ssh ${PI_USER}@${PI_IP} 'sudo journalctl -u k3s -n 50'${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Kubeconfig not found at ${KUBECONFIG_PATH}${NC}"
    echo -e "${YELLOW}  Troubleshooting:${NC}"
    echo -e "${BLUE}    - Re-run Ansible k3s installation: cd ansible && ansible-playbook playbooks/install-k3s.yml${NC}"
    exit 1
fi

echo ""

# Bootstrap FluxCD (optional)
echo -e "${YELLOW}[7/7] Bootstrap FluxCD GitOps? (y/n)${NC}"
read -p "> " BOOTSTRAP_FLUX

if [ "${BOOTSTRAP_FLUX}" = "y" ] || [ "${BOOTSTRAP_FLUX}" = "Y" ]; then
    echo -e "${BLUE}  Bootstrapping FluxCD with Ansible...${NC}"
    cd "${ANSIBLE_DIR}"
    
    ansible-playbook playbooks/bootstrap-flux.yml \
      -e bootstrap_flux=true \
      -e kubeconfig_path="${KUBECONFIG_PATH}" \
      || {
        echo -e "${YELLOW}  ⚠️  Flux bootstrap failed (may already be bootstrapped or need GitHub token)${NC}"
        echo -e "${YELLOW}  You can bootstrap manually later with:${NC}"
        echo -e "${BLUE}    export KUBECONFIG=${KUBECONFIG_PATH}${NC}"
        echo -e "${BLUE}    flux bootstrap github --owner=raolivei --repository=raolivei --branch=main --path=clusters/eldertree --personal${NC}"
      }
    
    echo -e "${GREEN}✓ FluxCD bootstrap complete${NC}"
    
    # Wait for Vault to be deployed (if FluxCD was bootstrapped)
    echo ""
    echo -e "${YELLOW}[8/8] Waiting for Vault to be deployed...${NC}"
    echo -e "${BLUE}  This may take a few minutes for FluxCD to deploy Vault...${NC}"
    
    MAX_VAULT_WAIT=30
    VAULT_WAIT_COUNT=0
    VAULT_READY=false
    
    while [ $VAULT_WAIT_COUNT -lt $MAX_VAULT_WAIT ]; do
        if kubectl get pods -n vault -l app.kubernetes.io/name=vault &>/dev/null; then
            VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
            if [ -n "${VAULT_POD}" ]; then
                VAULT_STATUS=$(kubectl get pod -n vault "${VAULT_POD}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
                if [ "${VAULT_STATUS}" = "Running" ]; then
                    VAULT_READY=true
                    break
                fi
            fi
        fi
        VAULT_WAIT_COUNT=$((VAULT_WAIT_COUNT + 1))
        echo -e "${YELLOW}  Waiting for Vault... (${VAULT_WAIT_COUNT}/${MAX_VAULT_WAIT})${NC}"
        sleep 10
    done
    
    if [ "${VAULT_READY}" = true ]; then
        echo -e "${GREEN}✓ Vault is deployed${NC}"
        echo ""
        echo -e "${BLUE}  Next steps for Cloudflare integration:${NC}"
        echo -e "${BLUE}    1. Initialize and unseal Vault (if not done):${NC}"
        echo -e "${BLUE}       ./scripts/unseal-vault.sh${NC}"
        echo -e "${BLUE}    2. Store Cloudflare API token in Vault:${NC}"
        echo -e "${BLUE}       VAULT_POD=\$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')${NC}"
        echo -e "${BLUE}       kubectl exec -n vault \$VAULT_POD -- vault kv put secret/pi-fleet/terraform/cloudflare-api-token api-token='YOUR_TOKEN'${NC}"
        echo -e "${BLUE}    3. Re-run Terraform to create Cloudflare resources:${NC}"
        echo -e "${BLUE}       cd terraform && ./run-terraform.sh apply${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Vault not ready yet (may still be deploying)${NC}"
        echo -e "${BLUE}  Check status: kubectl get pods -n vault${NC}"
        echo -e "${BLUE}  Once Vault is ready, follow steps above to add Cloudflare integration${NC}"
    fi
else
    echo -e "${YELLOW}  Skipping FluxCD bootstrap${NC}"
    echo -e "${YELLOW}  Bootstrap manually later with:${NC}"
    echo -e "${BLUE}    cd ${ANSIBLE_DIR}${NC}"
    echo -e "${BLUE}    ansible-playbook playbooks/bootstrap-flux.yml -e bootstrap_flux=true${NC}"
fi

echo ""
echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo "Summary:"
echo "  ✓ System configuration: Complete"
echo "  ✓ k3s installation: Complete"
if [ "${BOOTSTRAP_FLUX}" = "y" ] || [ "${BOOTSTRAP_FLUX}" = "Y" ]; then
    echo "  ✓ FluxCD bootstrap: Complete"
else
    echo "  - FluxCD bootstrap: Skipped"
fi
echo ""
echo "Next steps:"
echo "  1. Verify cluster: kubectl get nodes --kubeconfig=${KUBECONFIG_PATH}"
echo "  2. Check FluxCD: flux get all --kubeconfig=${KUBECONFIG_PATH}"
echo "  3. Monitor deployments: kubectl get pods -A --kubeconfig=${KUBECONFIG_PATH} -w"
echo "  4. Restore Vault secrets (if needed)"
echo ""
echo "Useful commands:"
echo "  export KUBECONFIG=${KUBECONFIG_PATH}"
echo "  kubectl get pods -A"
echo "  flux get all"
echo ""
echo "To re-run setup (idempotent):"
echo "  ${0}"
echo ""

