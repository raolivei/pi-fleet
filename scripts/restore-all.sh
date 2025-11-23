#!/bin/bash
set -e

# Restore script for eldertree cluster backups
# Usage: ./restore-all.sh <backup-directory>

if [ -z "$1" ]; then
    echo "Usage: $0 <backup-directory>"
    echo ""
    echo "Example:"
    echo "  $0 /mnt/backup/backups/20250118-123000"
    echo ""
    echo "Available backups:"
    ls -1d /mnt/backup/backups/*/ 2>/dev/null | tail -5 || echo "  No backups found"
    exit 1
fi

BACKUP_DIR="$1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}❌ Backup directory not found: $BACKUP_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}=== Eldertree Cluster Restore ==="
echo "Backup Directory: ${BACKUP_DIR}"
echo "===========================================${NC}"
echo ""

# Check if KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
    echo -e "${YELLOW}⚠️  KUBECONFIG not set. Setting to eldertree cluster...${NC}"
    export KUBECONFIG=~/.kube/config-eldertree
fi

# Confirm restore
echo -e "${YELLOW}⚠️  WARNING: This will restore data from backup!${NC}"
echo -e "${YELLOW}⚠️  Make sure you have a current backup before proceeding.${NC}"
echo ""
read -p "Continue with restore? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

# Function to restore PostgreSQL database
restore_postgres() {
    local namespace=$1
    local db_name=$2
    local backup_file=$3
    
    echo -e "${YELLOW}📦 Restoring PostgreSQL: ${namespace}/${db_name}${NC}"
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${YELLOW}  ⚠️  Backup file not found: $backup_file${NC}"
        return
    fi
    
    # Find postgres pod
    local pod_name=$(kubectl get pods -n "${namespace}" -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
                     kubectl get pods -n "${namespace}" -l component=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        echo -e "${RED}  ✗ PostgreSQL pod not found in namespace ${namespace}${NC}"
        return
    fi
    
    echo -e "  Using pod: ${pod_name}"
    
    # Drop and recreate database (WARNING: This destroys existing data!)
    echo -e "${YELLOW}  ⚠️  Dropping existing database...${NC}"
    kubectl exec -n "${namespace}" "${pod_name}" -- \
        psql -U postgres -c "DROP DATABASE IF EXISTS ${db_name};" 2>/dev/null || true
    
    kubectl exec -n "${namespace}" "${pod_name}" -- \
        psql -U postgres -c "CREATE DATABASE ${db_name};" 2>/dev/null || true
    
    # Restore from backup
    echo -e "  Restoring from backup..."
    gunzip -c "$backup_file" | kubectl exec -i -n "${namespace}" "${pod_name}" -- \
        psql -U postgres "${db_name}" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ Database restored successfully${NC}"
    else
        echo -e "${RED}  ✗ Failed to restore database${NC}"
    fi
}

# Function to restore Vault secrets
restore_vault() {
    local vault_backup=$(find "${BACKUP_DIR}/vault" -name "*.json" | head -1)
    
    if [ -z "$vault_backup" ]; then
        echo -e "${YELLOW}  ⚠️  No Vault backup found${NC}"
        return
    fi
    
    echo -e "${YELLOW}🔐 Restoring Vault secrets...${NC}"
    
    if [ -f "./restore-vault-secrets.sh" ]; then
        ./restore-vault-secrets.sh "$vault_backup"
    else
        echo -e "${YELLOW}  ⚠️  restore-vault-secrets.sh not found${NC}"
    fi
}

# Function to restore PVC data
restore_pvc() {
    local namespace=$1
    local pvc_name=$2
    local backup_file=$3
    
    echo -e "${YELLOW}💾 Restoring PVC: ${namespace}/${pvc_name}${NC}"
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${YELLOW}  ⚠️  Backup file not found: $backup_file${NC}"
        return
    fi
    
    # Find pod using this PVC
    local pod_name=$(kubectl get pods -n "${namespace}" -o json | \
        jq -r ".items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName==\"${pvc_name}\") | .metadata.name" | head -1)
    
    if [ -z "$pod_name" ]; then
        echo -e "${YELLOW}  ⚠️  No pod found using PVC ${pvc_name}${NC}"
        return
    fi
    
    # Get mount path
    local mount_path=$(kubectl get pod "${pod_name}" -n "${namespace}" -o json | \
        jq -r ".spec.containers[0].volumeMounts[] | select(.name | contains(\"${pvc_name}\") or .name | contains(\"storage\")) | .mountPath" | head -1)
    
    if [ -z "$mount_path" ]; then
        echo -e "${YELLOW}  ⚠️  Could not determine mount path${NC}"
        return
    fi
    
    echo -e "  Restoring to pod: ${pod_name}, mount: ${mount_path}"
    
    # Extract backup to pod
    cat "$backup_file" | kubectl exec -i -n "${namespace}" "${pod_name}" -- \
        tar xzf - -C "${mount_path}" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ PVC restored successfully${NC}"
    else
        echo -e "${RED}  ✗ Failed to restore PVC${NC}"
    fi
}

# Restore databases
echo -e "${GREEN}[1/3] Restoring databases...${NC}"
for backup_file in "${BACKUP_DIR}"/databases/*.sql.gz; do
    if [ -f "$backup_file" ]; then
        filename=$(basename "$backup_file")
        if [[ $filename =~ ^(swimto|journey)-([^-]+)-.*\.sql\.gz$ ]]; then
            namespace="${BASH_REMATCH[1]}"
            db_name="${BASH_REMATCH[2]}"
            restore_postgres "$namespace" "$db_name" "$backup_file"
        fi
    fi
done

# Restore Vault secrets
echo ""
echo -e "${GREEN}[2/3] Restoring Vault secrets...${NC}"
restore_vault

# Restore PVCs
echo ""
echo -e "${GREEN}[3/3] Restoring PVC data...${NC}"
for backup_file in "${BACKUP_DIR}"/pvcs/*.tar.gz; do
    if [ -f "$backup_file" ]; then
        filename=$(basename "$backup_file")
        if [[ $filename =~ ^([^-]+)-([^-]+)-.*\.tar\.gz$ ]]; then
            namespace="${BASH_REMATCH[1]}"
            pvc_name="${BASH_REMATCH[2]}"
            restore_pvc "$namespace" "$pvc_name" "$backup_file"
        fi
    fi
done

echo ""
echo -e "${GREEN}=== Restore Complete ==="
echo "Please verify your services are working correctly."
echo "You may need to restart pods for changes to take effect."
echo "===================================${NC}"

