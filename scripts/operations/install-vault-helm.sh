#!/bin/bash
# Install Vault using Helm
# Usage: ./install-vault-helm.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-eldertree}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_FLEET_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔧 Installing Vault with Helm${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

# Check if helm is available
if ! command -v helm &>/dev/null; then
    echo -e "${RED}❌ Helm is not installed${NC}"
    echo "   Install Helm: https://helm.sh/docs/intro/install/"
    exit 1
fi

# Check cluster connectivity
echo -e "${YELLOW}[1/6] Checking cluster connectivity...${NC}"
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}❌ Cannot connect to cluster${NC}"
    echo "   Please ensure:"
    echo "   1. KUBECONFIG is set correctly: export KUBECONFIG=~/.kube/config-eldertree"
    echo "   2. Cluster is running: kubectl cluster-info"
    exit 1
fi
echo -e "${GREEN}✅ Cluster accessible${NC}"
echo ""

# Create namespace if it doesn't exist
echo -e "${YELLOW}[2/6] Checking namespace...${NC}"
if ! kubectl get namespace vault &>/dev/null; then
    echo "   Creating vault namespace..."
    kubectl create namespace vault
    echo -e "${GREEN}✅ Namespace created${NC}"
else
    echo -e "${GREEN}✅ Namespace exists${NC}"
fi
echo ""

# Add HashiCorp Helm repository
echo -e "${YELLOW}[3/6] Adding HashiCorp Helm repository...${NC}"
if ! helm repo list | grep -q hashicorp; then
    helm repo add hashicorp https://helm.releases.hashicorp.com
    echo "   Repository added"
fi
helm repo update hashicorp
echo -e "${GREEN}✅ Repository ready${NC}"
echo ""

# Check if Vault is already installed
echo -e "${YELLOW}[4/6] Checking existing installation...${NC}"
if helm list -n vault | grep -q vault; then
    echo -e "${YELLOW}⚠️  Vault is already installed${NC}"
    echo "   Current installation:"
    helm list -n vault
    echo ""
    read -p "Upgrade existing installation? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    UPGRADE=true
else
    UPGRADE=false
fi
echo ""

# Install/Upgrade Vault
echo -e "${YELLOW}[5/6] Installing Vault...${NC}"

# Values for Vault installation
VALUES=$(cat <<EOF
server:
  dev:
    enabled: false  # Production mode with persistence
  
  # Enable persistence for secrets
  dataStorage:
    enabled: true
    size: 10Gi
    storageClass: local-path
    accessMode: ReadWriteOnce
  
  # Standalone mode (single-node cluster)
  ha:
    enabled: false
  standalone:
    enabled: true
    config: |
      ui = true
      
      listener "tcp" {
        tls_disable = 1
        address = "[::]:8200"
        cluster_address = "[::]:8201"
      }
      
      storage "file" {
        path = "/vault/data"
      }
      
      # Disable mlock for non-root containers
      disable_mlock = true
  
  replicas: 1
  ui:
    enabled: true
    serviceType: ClusterIP
  ingress:
    enabled: true
    ingressClassName: traefik
    hosts:
      - host: vault.eldertree.local
    tls:
      - secretName: vault-tls
        hosts:
          - vault.eldertree.local
    annotations:
      cert-manager.io/cluster-issuer: selfsigned-cluster-issuer
injector:
  enabled: true
EOF
)

if [ "$UPGRADE" = true ]; then
    echo "   Upgrading Vault..."
    helm upgrade vault hashicorp/vault \
        --namespace vault \
        --version 0.28.1 \
        --values <(echo "$VALUES") \
        --wait --timeout=10m
    echo -e "${GREEN}✅ Vault upgraded${NC}"
else
    echo "   Installing Vault..."
    helm install vault hashicorp/vault \
        --namespace vault \
        --version 0.28.1 \
        --values <(echo "$VALUES") \
        --wait --timeout=10m
    echo -e "${GREEN}✅ Vault installed${NC}"
fi
echo ""

# Wait for pod to be ready
echo -e "${YELLOW}[6/6] Waiting for Vault pod...${NC}"
kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=300s || {
    echo -e "${YELLOW}⚠️  Pod not ready yet, checking status...${NC}"
    kubectl get pods -n vault
    exit 1
}
echo -e "${GREEN}✅ Vault pod is ready${NC}"
echo ""

# Step 7: Initialize Vault (if needed)
echo -e "${YELLOW}[7/8] Checking Vault initialization...${NC}"
INIT_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.initialized' || echo "false")

if [ "$INIT_STATUS" = "false" ]; then
    echo "   Vault is not initialized, initializing now..."
    
    # Create backup directory
    BACKUP_DIR="$PI_FLEET_DIR/backups/vault-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Initialize Vault
    INIT_OUTPUT=$(kubectl exec -n vault vault-0 -- vault operator init -format=json 2>/dev/null)
    
    if [ -z "$INIT_OUTPUT" ]; then
        echo -e "${RED}❌ Failed to initialize Vault${NC}"
        exit 1
    fi
    
    # Save credentials
    echo "$INIT_OUTPUT" > "$BACKUP_DIR/vault-init.json"
    ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')
    echo "$ROOT_TOKEN" > "$BACKUP_DIR/vault-root-token.txt"
    
    echo -e "${GREEN}✅ Vault initialized${NC}"
    echo -e "${YELLOW}⚠️  CRITICAL: Save these credentials!${NC}"
    echo "   Backup directory: $BACKUP_DIR"
    echo "   Root token: $ROOT_TOKEN"
    echo ""
    echo "   Unseal Keys:"
    echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[]' | nl -v 1 | while read num key; do
        echo "     Key $num: $key"
    done
    echo ""
    
    # Unseal Vault
    echo -e "${YELLOW}[8/8] Unsealing Vault...${NC}"
    UNSEAL_KEYS=($(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[]'))
    
    for i in 0 1 2; do
        echo "   Unsealing with key $((i+1))..."
        kubectl exec -n vault vault-0 -- vault operator unseal "${UNSEAL_KEYS[$i]}" &>/dev/null
    done
    
    # Verify unsealed
    SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
    if [ "$SEAL_STATUS" = "false" ]; then
        echo -e "${GREEN}✅ Vault unsealed${NC}"
        
        # Login and restore secrets if backup exists
        echo ""
        echo "   Logging in..."
        kubectl exec -n vault vault-0 -- vault login -method=token token="$ROOT_TOKEN" &>/dev/null
        
        # Check for backup file
        BACKUP_FILE="$PI_FLEET_DIR/vault-backup-20251115-163624.json"
        if [ -f "$BACKUP_FILE" ]; then
            echo "   Restoring secrets from backup..."
            if [ -f "$PI_FLEET_DIR/scripts/operations/restore-vault-secrets.sh" ]; then
                "$PI_FLEET_DIR/scripts/operations/restore-vault-secrets.sh" "$BACKUP_FILE"
                echo -e "${GREEN}✅ Secrets restored${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Backup file not found, skipping restore${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to unseal Vault${NC}"
    fi
else
    echo -e "${GREEN}✅ Vault is already initialized${NC}"
    echo "   Skipping initialization (Vault already has data)"
fi
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Vault Installation Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "📋 Status:"
kubectl get pods -n vault
echo ""

if [ "$INIT_STATUS" = "false" ]; then
    echo "🔐 Credentials saved to: $BACKUP_DIR"
    echo "   - Init file: $BACKUP_DIR/vault-init.json"
    echo "   - Root token: $BACKUP_DIR/vault-root-token.txt"
    echo ""
fi

echo "📝 Next steps:"
echo "   1. Check status: kubectl exec -n vault vault-0 -- vault status"
echo "   2. List secrets: kubectl exec -n vault vault-0 -- vault kv list secret/"
echo "   3. Update External Secrets Operator token if needed"
echo ""

