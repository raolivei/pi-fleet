#!/bin/bash
set -euo pipefail

# Comprehensive backup script for eldertree cluster
# Backs up: PostgreSQL databases, Vault secrets, Kubernetes configs, PVCs
# Usage: ./backup-all.sh [backup-dir]

BACKUP_DIR="${1:-/mnt/backup}"
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_ROOT="${BACKUP_DIR}/backups/${BACKUP_DATE}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Eldertree Cluster Backup ==="
echo "Backup Date: $(date)"
echo "Backup Directory: ${BACKUP_ROOT}"
echo "===========================================${NC}"
echo ""

# Check if KUBECONFIG is set and valid
if [ -z "$KUBECONFIG" ]; then
    if [ -f ~/.kube/config-eldertree ]; then
        echo -e "${YELLOW}⚠️  KUBECONFIG not set. Setting to eldertree cluster...${NC}"
        export KUBECONFIG=~/.kube/config-eldertree
    else
        echo -e "${YELLOW}⚠️  KUBECONFIG not set. Trying default location...${NC}"
        export KUBECONFIG=~/.kube/config
    fi
fi

# Verify kubectl can connect
if ! kubectl get nodes &>/dev/null; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster!${NC}"
    echo -e "${RED}   Check KUBECONFIG: $KUBECONFIG${NC}"
    echo -e "${YELLOW}   Trying to use default k3s config...${NC}"
    if [ -f /etc/rancher/k3s/k3s.yaml ]; then
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        if ! kubectl get nodes &>/dev/null; then
            echo -e "${RED}❌ Still cannot connect. Please check cluster status.${NC}"
            exit 1
        fi
    else
        exit 1
    fi
fi

# Check if backup directory exists and is writable
if [ ! -d "$BACKUP_DIR" ] || [ ! -w "$BACKUP_DIR" ]; then
    echo -e "${RED}❌ Backup directory ${BACKUP_DIR} does not exist or is not writable!${NC}"
    exit 1
fi

# Create backup directory structure
mkdir -p "${BACKUP_ROOT}"/{databases,vault,kubernetes,pvcs,configs}
echo -e "${GREEN}✓ Created backup directory structure${NC}"

# Function to backup PostgreSQL database
backup_postgres() {
    local namespace=$1
    local pod_name=$2
    local db_name=$3
    local backup_file="${BACKUP_ROOT}/databases/${namespace}-${db_name}-${BACKUP_DATE}.sql.gz"
    
    echo -e "${YELLOW}📦 Backing up PostgreSQL: ${namespace}/${pod_name} (database: ${db_name})${NC}"
    
    if kubectl get pod "${pod_name}" -n "${namespace}" &>/dev/null; then
        kubectl exec -n "${namespace}" "${pod_name}" -- \
            pg_dump -U postgres "${db_name}" 2>/dev/null | gzip > "${backup_file}"
        
        if [ -f "${backup_file}" ] && [ -s "${backup_file}" ]; then
            echo -e "${GREEN}  ✓ Database backup created: $(du -h ${backup_file} | cut -f1)${NC}"
        else
            echo -e "${RED}  ✗ Failed to create database backup${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠️  Pod ${pod_name} not found in namespace ${namespace}, skipping...${NC}"
    fi
}

# Function to backup Vault secrets
backup_vault() {
    echo -e "${YELLOW}🔐 Backing up Vault secrets...${NC}"
    
    if ! kubectl get pod vault-0 -n vault &>/dev/null; then
        echo -e "${YELLOW}  ⚠️  Vault pod not found, skipping Vault backup${NC}"
        return
    fi
    
    # Check if Vault is unsealed
    SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
    if [ "$SEAL_STATUS" = "true" ]; then
        echo -e "${YELLOW}  ⚠️  Vault is sealed. Skipping Vault backup (unseal first to backup secrets)${NC}"
        return
    fi
    
    # Use existing backup script (check multiple locations)
    local vault_backup="${BACKUP_ROOT}/vault/vault-secrets-${BACKUP_DATE}.json"
    local backup_script=""
    
    for script_path in "./backup-vault-secrets.sh" "~/backup-vault-secrets.sh" "/home/raolivei/backup-vault-secrets.sh"; do
        if [ -f "$script_path" ] || [ -f "${script_path/#\~/$HOME}" ]; then
            backup_script="${script_path/#\~/$HOME}"
            break
        fi
    done
    
    if [ -n "$backup_script" ] && [ -f "$backup_script" ]; then
        bash "$backup_script" > "${vault_backup}" 2>&1
        if [ -f "${vault_backup}" ] && [ -s "${vault_backup}" ]; then
            echo -e "${GREEN}  ✓ Vault secrets backup created: $(du -h ${vault_backup} | cut -f1)${NC}"
        else
            echo -e "${RED}  ✗ Failed to create Vault backup${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠️  backup-vault-secrets.sh not found, using direct vault commands...${NC}"
        # Fallback: direct vault backup
        local vault_backup_direct="${BACKUP_ROOT}/vault/vault-secrets-direct-${BACKUP_DATE}.json"
        kubectl exec -n vault vault-0 -- vault kv list secret/ 2>/dev/null > "${vault_backup_direct}.list" || true
        echo -e "${YELLOW}  ⚠️  Vault list saved to ${vault_backup_direct}.list (manual restore required)${NC}"
    fi
}

# Function to backup Kubernetes resources
backup_kubernetes() {
    echo -e "${YELLOW}☸️  Backing up Kubernetes resources...${NC}"
    
    # Backup all namespaces
    kubectl get namespaces -o json > "${BACKUP_ROOT}/kubernetes/namespaces.json" 2>/dev/null || true
    
    # Backup important resources per namespace
    for namespace in swimto journey canopy nima vault pihole observability wireguard; do
        if kubectl get namespace "${namespace}" &>/dev/null; then
            echo -e "  📋 Backing up namespace: ${namespace}"
            mkdir -p "${BACKUP_ROOT}/kubernetes/${namespace}"
            
            # Backup deployments, services, configmaps, secrets (metadata only)
            kubectl get all -n "${namespace}" -o yaml > "${BACKUP_ROOT}/kubernetes/${namespace}/resources.yaml" 2>/dev/null || true
            kubectl get configmap -n "${namespace}" -o yaml > "${BACKUP_ROOT}/kubernetes/${namespace}/configmaps.yaml" 2>/dev/null || true
            kubectl get secret -n "${namespace}" -o yaml > "${BACKUP_ROOT}/kubernetes/${namespace}/secrets.yaml" 2>/dev/null || true
            kubectl get pvc -n "${namespace}" -o yaml > "${BACKUP_ROOT}/kubernetes/${namespace}/pvcs.yaml" 2>/dev/null || true
        fi
    done
    
    echo -e "${GREEN}  ✓ Kubernetes resources backed up${NC}"
}

# Function to backup PVC data
backup_pvc() {
    echo -e "${YELLOW}💾 Backing up PVC data...${NC}"
    
    # Get all PVCs
    kubectl get pvc --all-namespaces -o json | jq -r '.items[] | "\(.metadata.namespace)|\(.metadata.name)|\(.spec.volumeName)"' | while IFS='|' read -r namespace pvc_name volume_name; do
        if [ -z "$volume_name" ] || [ "$volume_name" = "null" ]; then
            continue
        fi
        
        echo -e "  📦 Backing up PVC: ${namespace}/${pvc_name}"
        
        # Find the pod using this PVC
        local pod_name=$(kubectl get pods -n "${namespace}" -o json | \
            jq -r ".items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName==\"${pvc_name}\") | .metadata.name" | head -1)
        
        if [ -n "$pod_name" ]; then
            local backup_file="${BACKUP_ROOT}/pvcs/${namespace}-${pvc_name}-${BACKUP_DATE}.tar.gz"
            
            # Get mount path from pod
            local mount_path=$(kubectl get pod "${pod_name}" -n "${namespace}" -o json | \
                jq -r ".spec.containers[0].volumeMounts[] | select(.name | contains(\"${pvc_name}\") or .name | contains(\"storage\")) | .mountPath" | head -1)
            
            if [ -n "$mount_path" ]; then
                # Create backup using kubectl exec and tar
                kubectl exec -n "${namespace}" "${pod_name}" -- \
                    tar czf - -C "${mount_path}" . 2>/dev/null > "${backup_file}" || true
                
                if [ -f "${backup_file}" ] && [ -s "${backup_file}" ]; then
                    echo -e "${GREEN}    ✓ PVC backup created: $(du -h ${backup_file} | cut -f1)${NC}"
                else
                    echo -e "${YELLOW}    ⚠️  PVC backup empty or failed${NC}"
                fi
            fi
        else
            echo -e "${YELLOW}    ⚠️  No pod found using PVC ${pvc_name}${NC}"
        fi
    done
}

# Function to backup important config files
backup_configs() {
    echo -e "${YELLOW}⚙️  Backing up configuration files...${NC}"
    
    # Backup k3s config
    if [ -f /etc/rancher/k3s/k3s.yaml ]; then
        sudo cp /etc/rancher/k3s/k3s.yaml "${BACKUP_ROOT}/configs/k3s.yaml" 2>/dev/null || true
    fi
    
    # Backup fstab
    cp /etc/fstab "${BACKUP_ROOT}/configs/fstab" 2>/dev/null || true
    
    # Backup network config
    if [ -f /etc/netplan ]; then
        sudo cp -r /etc/netplan "${BACKUP_ROOT}/configs/" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}  ✓ Configuration files backed up${NC}"
}

# Create backup manifest
create_manifest() {
    local manifest="${BACKUP_ROOT}/BACKUP_MANIFEST.txt"
    cat > "${manifest}" <<EOF
Eldertree Cluster Backup Manifest
==================================
Backup Date: $(date)
Backup Location: ${BACKUP_ROOT}
Cluster: eldertree

Backup Contents:
- PostgreSQL Databases: $(ls -1 ${BACKUP_ROOT}/databases/*.sql.gz 2>/dev/null | wc -l) files
- Vault Secrets: $(ls -1 ${BACKUP_ROOT}/vault/*.json 2>/dev/null | wc -l) files
- Kubernetes Resources: $(find ${BACKUP_ROOT}/kubernetes -type f 2>/dev/null | wc -l) files
- PVC Backups: $(ls -1 ${BACKUP_ROOT}/pvcs/*.tar.gz 2>/dev/null | wc -l) files
- Config Files: $(ls -1 ${BACKUP_ROOT}/configs/* 2>/dev/null | wc -l) files

Total Backup Size: $(du -sh ${BACKUP_ROOT} | cut -f1)

Restore Instructions:
- See restore-all.sh script for automated restore
- Or restore manually using kubectl and database restore commands
EOF
    echo -e "${GREEN}✓ Backup manifest created${NC}"
}

# Main backup execution
echo ""
echo -e "${GREEN}Starting backup process...${NC}"
echo ""

# Backup PostgreSQL databases
echo -e "${GREEN}[1/5] Backing up databases...${NC}"

# Backup swimTO PostgreSQL
SWIMTO_POD=$(kubectl get pods -n swimto -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$SWIMTO_POD" ]; then
    backup_postgres "swimto" "$SWIMTO_POD" "pools"
else
    echo -e "${YELLOW}  ⚠️  swimTO PostgreSQL pod not found, skipping...${NC}"
fi

# Backup journey PostgreSQL
JOURNEY_POD=$(kubectl get pods -n journey -l component=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$JOURNEY_POD" ]; then
    backup_postgres "journey" "$JOURNEY_POD" "journey" || echo -e "${YELLOW}  ⚠️  Failed to backup journey database${NC}"
else
    echo -e "${YELLOW}  ⚠️  Journey PostgreSQL pod not found, skipping...${NC}"
fi

# Backup Vault secrets
echo ""
echo -e "${GREEN}[2/5] Backing up Vault secrets...${NC}"
backup_vault || echo -e "${YELLOW}  ⚠️  Vault backup failed, continuing...${NC}"

# Backup Kubernetes resources
echo ""
echo -e "${GREEN}[3/5] Backing up Kubernetes resources...${NC}"
backup_kubernetes || echo -e "${YELLOW}  ⚠️  Kubernetes backup failed, continuing...${NC}"

# Backup PVC data
echo ""
echo -e "${GREEN}[4/5] Backing up PVC data...${NC}"
backup_pvc || echo -e "${YELLOW}  ⚠️  PVC backup failed, continuing...${NC}"

# Backup config files
echo ""
echo -e "${GREEN}[5/5] Backing up configuration files...${NC}"
backup_configs || echo -e "${YELLOW}  ⚠️  Config backup failed, continuing...${NC}"

# Create manifest
create_manifest || echo -e "${YELLOW}  ⚠️  Manifest creation failed${NC}"

# Summary
echo ""
echo -e "${GREEN}=== Backup Complete ==="
echo "Backup Location: ${BACKUP_ROOT}"
echo "Total Size: $(du -sh ${BACKUP_ROOT} | cut -f1)"
echo "===============================${NC}"
echo ""
echo "Backup contents:"
ls -lhR "${BACKUP_ROOT}" | head -30
echo ""
echo -e "${GREEN}✅ All backups completed successfully!${NC}"

