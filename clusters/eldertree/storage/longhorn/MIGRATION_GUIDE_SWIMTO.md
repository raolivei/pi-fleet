# SwimTO PostgreSQL Migration Guide: local-path → Longhorn

Step-by-step guide to migrate swimto PostgreSQL database from `local-path` to Longhorn storage.

## Overview

**Source**: `local-path` storage class (10Gi)  
**Target**: `longhorn` storage class (10Gi)  
**Method**: Database backup/restore (pg_dump/pg_restore)  
**Estimated Downtime**: 15-30 minutes  
**Risk Level**: Medium

## Prerequisites

- ✅ Longhorn is deployed and operational
- ✅ Longhorn StorageClass is available
- ✅ Database backup tools available (pg_dump)
- ✅ Access to swimto namespace and secrets
- ✅ Maintenance window scheduled

## Pre-Migration Checklist

### 1. Verify Current State

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check current PVC
kubectl get pvc postgres-pvc -n swimto

# Check postgres pod
kubectl get pod -n swimto -l app=postgres

# Verify database is accessible
kubectl exec -n swimto -it $(kubectl get pod -n swimto -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- \
  psql -U postgres -d pools -c "SELECT COUNT(*) FROM information_schema.tables;"
```

### 2. Check Longhorn Status

```bash
# Verify Longhorn is ready
kubectl get pods -n longhorn-system | grep -E "manager|ui"

# Verify StorageClass exists
kubectl get storageclass longhorn

# Check available storage
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.capacity.storage}{"\n"}{end}'
```

### 3. Get Database Credentials

```bash
# Get postgres password from secret
kubectl get secret swimto-secrets -n swimto -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
# Save this password - you'll need it for restore
```

## Migration Steps

### Step 1: Create Database Backup

**⚠️ CRITICAL**: This backup is your safety net. Verify it completes successfully before proceeding.

```bash
export KUBECONFIG=~/.kube/config-eldertree
export NAMESPACE=swimto
export BACKUP_DIR=/tmp/swimto-migration-$(date +%Y%m%d-%H%M%S)
mkdir -p $BACKUP_DIR

# Get postgres pod name
POSTGRES_POD=$(kubectl get pod -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# Get postgres password
POSTGRES_PASSWORD=$(kubectl get secret swimto-secrets -n $NAMESPACE -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)

# Create backup
echo "Creating database backup..."
kubectl exec -n $NAMESPACE $POSTGRES_POD -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  pg_dump -U postgres -d pools -F c -f /tmp/swimto-backup.dump

# Copy backup to local machine
kubectl cp $NAMESPACE/$POSTGRES_POD:/tmp/swimto-backup.dump $BACKUP_DIR/swimto-backup.dump

# Verify backup file exists and has content
ls -lh $BACKUP_DIR/swimto-backup.dump
file $BACKUP_DIR/swimto-backup.dump

echo "✅ Backup created: $BACKUP_DIR/swimto-backup.dump"
echo "📋 Backup size: $(du -h $BACKUP_DIR/swimto-backup.dump | cut -f1)"
```

**Verification**: Check backup file size (should be > 0). For a 10Gi database, backup might be 100MB-1GB depending on data.

### Step 2: Scale Down swimto API (Optional but Recommended)

To prevent writes during migration:

```bash
# Scale down API to prevent new writes
kubectl scale deployment swimto-api -n swimto --replicas=0

# Wait for pods to terminate
kubectl wait --for=delete pod -n swimto -l app=swimto-api --timeout=60s

# Verify no active connections (optional)
kubectl exec -n swimto $POSTGRES_POD -- \
  psql -U postgres -d pools -c "SELECT count(*) FROM pg_stat_activity WHERE datname = 'pools';"
```

### Step 3: Create New PVC with Longhorn StorageClass

```bash
# Create new PVC manifest
cat > /tmp/swimto-postgres-pvc-longhorn.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc-longhorn
  namespace: swimto
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
EOF

# Apply new PVC
kubectl apply -f /tmp/swimto-postgres-pvc-longhorn.yaml

# Wait for PVC to be bound
kubectl wait --for=condition=Bound pvc/postgres-pvc-longhorn -n swimto --timeout=5m

# Verify PVC is bound
kubectl get pvc postgres-pvc-longhorn -n swimto
```

**Expected Output**:

```
NAME                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
postgres-pvc-longhorn     Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   10Gi       RWO            longhorn       30s
```

### Step 4: Update Postgres Deployment

**⚠️ IMPORTANT**: We'll update the deployment to use the new PVC, then delete the old one.

```bash
# Backup current deployment
kubectl get deployment postgres -n swimto -o yaml > $BACKUP_DIR/postgres-deployment-backup.yaml

# Update deployment to use new PVC
kubectl patch deployment postgres -n swimto --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/volumes/0/persistentVolumeClaim/claimName", "value": "postgres-pvc-longhorn"}]'

# Verify the change
kubectl get deployment postgres -n swimto -o jsonpath='{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}'
# Should output: postgres-pvc-longhorn
```

### Step 5: Delete Old Postgres Pod

This will trigger a new pod with the new PVC:

```bash
# Delete the postgres pod to force recreation with new PVC
kubectl delete pod -n swimto -l app=postgres

# Wait for new pod to be ready
kubectl wait --for=condition=Ready pod -n swimto -l app=postgres --timeout=5m

# Verify new pod is using Longhorn PVC
NEW_POSTGRES_POD=$(kubectl get pod -n swimto -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl get pod $NEW_POSTGRES_POD -n swimto -o jsonpath='{.spec.volumes[0].persistentVolumeClaim.claimName}'
# Should output: postgres-pvc-longhorn
```

### Step 6: Restore Database

The new pod will have an empty database. Restore from backup:

```bash
# Get new postgres pod name
NEW_POSTGRES_POD=$(kubectl get pod -n swimto -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# Copy backup to new pod
kubectl cp $BACKUP_DIR/swimto-backup.dump $NAMESPACE/$NEW_POSTGRES_POD:/tmp/swimto-backup.dump

# Get postgres password
POSTGRES_PASSWORD=$(kubectl get secret swimto-secrets -n $NAMESPACE -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)

# Drop existing database (it's empty, but ensure clean state)
kubectl exec -n $NAMESPACE $NEW_POSTGRES_POD -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  psql -U postgres -c "DROP DATABASE IF EXISTS pools;"

# Create new database
kubectl exec -n $NAMESPACE $NEW_POSTGRES_POD -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  psql -U postgres -c "CREATE DATABASE pools;"

# Restore database from backup
echo "Restoring database (this may take a few minutes)..."
kubectl exec -n $NAMESPACE $NEW_POSTGRES_POD -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  pg_restore -U postgres -d pools -v /tmp/swimto-backup.dump

# Verify restore completed
kubectl exec -n $NAMESPACE $NEW_POSTGRES_POD -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  psql -U postgres -d pools -c "SELECT COUNT(*) FROM information_schema.tables;"
```

### Step 7: Verify Database Integrity

```bash
# Check database size
kubectl exec -n $NAMESPACE $NEW_POSTGRES_POD -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  psql -U postgres -d pools -c "SELECT pg_size_pretty(pg_database_size('pools'));"

# Check table counts (adjust table names based on your schema)
kubectl exec -n $NAMESPACE $NEW_POSTGRES_POD -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  psql -U postgres -d pools -c "\dt"

# Test a sample query (adjust based on your schema)
kubectl exec -n $NAMESPACE $NEW_POSTGRES_POD -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  psql -U postgres -d pools -c "SELECT COUNT(*) FROM pg_stat_user_tables;"
```

### Step 8: Scale Up swimto API

```bash
# Scale API back up
kubectl scale deployment swimto-api -n swimto --replicas=1

# Wait for API to be ready
kubectl wait --for=condition=Ready pod -n swimto -l app=swimto-api --timeout=2m

# Verify API can connect to database
kubectl logs -n swimto -l app=swimto-api --tail=20
```

### Step 9: Verify Application Functionality

```bash
# Check API health endpoint (adjust based on your API)
kubectl exec -n swimto $(kubectl get pod -n swimto -l app=swimto-api -o jsonpath='{.items[0].metadata.name}') -- \
  wget -qO- http://localhost:8000/health || echo "Check API logs for connection issues"

# Check web frontend (if applicable)
kubectl get pods -n swimto -l app=swimto-web
```

### Step 10: Clean Up Old PVC (After Verification)

**⚠️ WAIT**: Only delete the old PVC after you've verified everything works for at least 24 hours.

```bash
# Verify new PVC is working
kubectl get pvc postgres-pvc-longhorn -n swimto

# Verify postgres is using new PVC
kubectl get pod -n swimto -l app=postgres -o jsonpath='{.items[0].spec.volumes[0].persistentVolumeClaim.claimName}'

# After 24 hours of successful operation, delete old PVC
# kubectl delete pvc postgres-pvc -n swimto
```

### Step 11: Update PVC Reference in Git (Optional)

If you want to update the PVC definition in git for future deployments:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet

# Update postgres-pvc.yaml
sed -i.bak 's/storageClassName: local-path/storageClassName: longhorn/' \
  clusters/eldertree/swimto/postgres-pvc.yaml

# Review changes
git diff clusters/eldertree/swimto/postgres-pvc.yaml

# Commit if satisfied
# git add clusters/eldertree/swimto/postgres-pvc.yaml
# git commit -m "feat: migrate swimto postgres to Longhorn storage"
# git push
```

## Rollback Procedure

If something goes wrong, rollback immediately:

### Quick Rollback

```bash
export KUBECONFIG=~/.kube/config-eldertree
export NAMESPACE=swimto

# 1. Scale down API
kubectl scale deployment swimto-api -n $NAMESPACE --replicas=0

# 2. Revert deployment to old PVC
kubectl patch deployment postgres -n $NAMESPACE --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/volumes/0/persistentVolumeClaim/claimName", "value": "postgres-pvc"}]'

# 3. Delete pod to force recreation
kubectl delete pod -n $NAMESPACE -l app=postgres

# 4. Wait for pod to be ready
kubectl wait --for=condition=Ready pod -n $NAMESPACE -l app=postgres --timeout=5m

# 5. Restore from backup if needed
# (Follow Step 6 restore procedure)

# 6. Scale API back up
kubectl scale deployment swimto-api -n $NAMESPACE --replicas=1
```

### Full Rollback (If New PVC Created Issues)

```bash
# Delete new PVC and deployment changes
kubectl delete pvc postgres-pvc-longhorn -n swimto

# Restore deployment from backup
kubectl apply -f $BACKUP_DIR/postgres-deployment-backup.yaml

# Delete and recreate pod
kubectl delete pod -n swimto -l app=postgres
kubectl wait --for=condition=Ready pod -n swimto -l app=postgres --timeout=5m

# Restore database from backup (Step 6)
```

## Verification Checklist

After migration, verify:

- [ ] New PVC is bound and using Longhorn StorageClass
- [ ] Postgres pod is running and healthy
- [ ] Database restore completed successfully
- [ ] Database contains expected data (table counts match)
- [ ] swimto API can connect to database
- [ ] swimto web frontend is accessible
- [ ] Application functionality works (test key features)
- [ ] No errors in postgres logs
- [ ] No errors in API logs
- [ ] Longhorn UI shows the volume with 2 replicas on different nodes

## Post-Migration Tasks

### 1. Monitor Longhorn Volume

```bash
# Check volume in Longhorn UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Open http://localhost:8080
# Navigate to: Volume → Find postgres-pvc-longhorn volume
# Verify:
#   - 2 replicas are on different nodes
#   - Volume is healthy
#   - No errors
```

### 2. Create Longhorn Snapshot (Optional)

```bash
# Create a snapshot via Longhorn UI or kubectl
# This provides a point-in-time backup
```

### 3. Update Documentation

Update any documentation that references the storage class.

## Troubleshooting

### Issue: New PVC Won't Bind

```bash
# Check Longhorn status
kubectl get pods -n longhorn-system | grep manager

# Check StorageClass
kubectl get storageclass longhorn

# Check node disk registration
# Access Longhorn UI and check Node section
```

### Issue: Database Restore Fails

```bash
# Check postgres logs
kubectl logs -n swimto -l app=postgres

# Verify backup file integrity
file $BACKUP_DIR/swimto-backup.dump

# Try restore with verbose output
kubectl exec -n swimto $NEW_POSTGRES_POD -- \
  env PGPASSWORD=$POSTGRES_PASSWORD \
  pg_restore -U postgres -d pools -v /tmp/swimto-backup.dump 2>&1 | tee restore.log
```

### Issue: API Can't Connect to Database

```bash
# Check postgres service
kubectl get svc postgres-service -n swimto

# Test connection from API pod
kubectl exec -n swimto $(kubectl get pod -n swimto -l app=swimto-api -o jsonpath='{.items[0].metadata.name}') -- \
  nc -zv postgres-service.swimto.svc.cluster.local 5432

# Check postgres logs for connection errors
kubectl logs -n swimto -l app=postgres --tail=50
```

## Expected Timeline

- **Pre-migration checks**: 5 minutes
- **Backup creation**: 2-5 minutes (depends on data size)
- **PVC creation**: 1-2 minutes
- **Deployment update**: 1 minute
- **Pod recreation**: 2-3 minutes
- **Database restore**: 5-15 minutes (depends on data size)
- **Verification**: 5 minutes
- **Total**: ~20-35 minutes

## Success Criteria

✅ Migration is successful when:

1. New PVC is bound with Longhorn StorageClass
2. Postgres pod is running with new PVC
3. Database restore completed without errors
4. Application is functional and accessible
5. Longhorn shows volume with 2 replicas on different nodes
6. No data loss (verify record counts match)

## Notes

- **Backup Location**: Backups are stored in `/tmp/swimto-migration-*` - move to permanent location if needed
- **Old PVC**: Keep old PVC for 24-48 hours before deletion as safety measure
- **Monitoring**: Watch Longhorn UI for volume health after migration
- **Performance**: Longhorn may have slightly different I/O characteristics than local-path

## Support

If issues arise:

1. Check postgres logs: `kubectl logs -n swimto -l app=postgres`
2. Check API logs: `kubectl logs -n swimto -l app=swimto-api`
3. Check Longhorn UI for volume status
4. Review rollback procedure if needed
