# Longhorn Storage Migration Assessment

Assessment of all projects in the ElderTree cluster to determine which should use Longhorn storage.

## Executive Summary

**Total Current Storage**: 32Gi across 5 active PVCs  
**Recommendation**: Migrate **swimto** and **canopy** (when enabled) to Longhorn. Keep others on local-path for now.

## Assessment Criteria

- **Data Criticality**: How important is the data?
- **Redundancy Need**: Does it need to survive node failures?
- **Performance**: Does it need high I/O performance?
- **Migration Complexity**: How difficult is migration?
- **Business Impact**: Commercial vs personal/homelab

## Projects Assessment

### ✅ **MIGRATE TO LONGHORN** (High Priority)

#### 1. **swimto** - PostgreSQL Database

- **Current**: 10Gi on `local-path`
- **Status**: ✅ ACTIVE (commercial project)
- **Criticality**: 🔴 HIGH - Commercial application
- **Redundancy Need**: ✅ YES - Business continuity important
- **Performance**: Medium (database I/O)
- **Migration Complexity**: Medium (requires backup/restore)
- **Recommendation**: **MIGRATE** - Commercial app needs redundancy

**Rationale**:

- Commercial project requires data protection
- PostgreSQL data is critical and should survive node failures
- Benefits from Longhorn snapshots and backups
- Worth the migration effort for business continuity

**Migration Priority**: **HIGH**

---

#### 2. **canopy** - Personal Finance Dashboard

- **Current**: 10Gi (StatefulSet with volumeClaimTemplate)
- **Status**: ⚠️ DISABLED (not currently deployed)
- **Criticality**: 🟡 MEDIUM - Personal financial data
- **Redundancy Need**: ✅ YES - Financial data should be protected
- **Performance**: Medium (database I/O)
- **Migration Complexity**: Low (not deployed yet, can configure from start)
- **Recommendation**: **USE LONGHORN** when enabled

**Rationale**:

- Financial data should have redundancy
- Not yet deployed - easy to configure correctly from start
- Personal data protection is important

**Migration Priority**: **N/A** (configure for Longhorn from start)

---

### ⚠️ **CONSIDER MIGRATING** (Medium Priority)

#### 3. **journey** - AI Career Pathfinder

- **Current**: 5Gi (defined but not deployed)
- **Status**: ⚠️ DISABLED
- **Criticality**: 🟢 LOW - Personal project
- **Redundancy Need**: ⚠️ MAYBE - Depends on usage
- **Performance**: Low (likely minimal I/O)
- **Migration Complexity**: Low (not deployed yet)
- **Recommendation**: **USE LONGHORN** if you plan to use it actively

**Rationale**:

- Easy to configure for Longhorn from start
- Low risk since not deployed
- Better to have redundancy if you'll use it

**Migration Priority**: **LOW** (configure for Longhorn when enabled)

---

### ❌ **KEEP ON LOCAL-PATH** (Low Priority / Not Recommended)

#### 4. **vault** - Secrets Management

- **Current**: 10Gi on `local-path`
- **Status**: ✅ ACTIVE
- **Criticality**: 🔴 HIGH - Secrets storage
- **Redundancy Need**: ⚠️ COMPLEX - Vault has built-in HA
- **Performance**: High (frequent I/O)
- **Migration Complexity**: 🔴 HIGH - Critical system, complex migration
- **Recommendation**: **KEEP ON LOCAL-PATH**

**Rationale**:

- Vault has its own HA mechanisms (if configured)
- Migration risk is high for critical secrets system
- Local-path is faster for single-node access
- Vault should be backed up separately (not just storage)
- If you need Vault HA, use Vault's native clustering, not storage redundancy

**Migration Priority**: **NO** - Keep as-is

---

#### 5. **observability** - Monitoring Stack

- **Prometheus**: 8Gi
- **Grafana**: 2Gi
- **Status**: ✅ ACTIVE
- **Criticality**: 🟡 MEDIUM - Monitoring data
- **Redundancy Need**: ❌ NO - Monitoring data is ephemeral
- **Performance**: High (time-series writes)
- **Migration Complexity**: Medium (requires reconfiguration)
- **Recommendation**: **KEEP ON LOCAL-PATH**

**Rationale**:

- Monitoring data is typically ephemeral (can be rebuilt)
- Prometheus has its own retention policies
- High write I/O - local-path is faster
- Loss of monitoring data is acceptable (can scrape again)
- Grafana dashboards are in git (not critical data)

**Migration Priority**: **NO** - Keep as-is

---

#### 6. **pihole** - DNS Server

- **Current**: 2Gi on `local-path`
- **Status**: ✅ ACTIVE
- **Criticality**: 🟡 MEDIUM - Network service
- **Redundancy Need**: ❌ NO - Can be rebuilt quickly
- **Performance**: Low (minimal I/O)
- **Migration Complexity**: Low (small volume)
- **Recommendation**: **KEEP ON LOCAL-PATH**

**Rationale**:

- Pi-hole data (blocklists, custom rules) can be rebuilt
- Small volume, not worth migration overhead
- DNS service should be fast (local-path is better)
- Custom rules can be backed up separately

**Migration Priority**: **NO** - Keep as-is

---

#### 7. **nima** - AI/ML Learning Project

- **Current**: 6Gi (model + tokenizer PVCs, defined but not deployed)
- **Status**: ⚠️ DISABLED
- **Criticality**: 🟢 LOW - Learning project
- **Redundancy Need**: ❌ NO - Models can be re-downloaded
- **Performance**: Medium (model loading)
- **Migration Complexity**: Low (not deployed)
- **Recommendation**: **USE LOCAL-PATH** or **NO STORAGE**

**Rationale**:

- ML models can be re-downloaded from source
- Learning project - data loss is acceptable
- Models are typically large but not critical
- Consider using container image layers instead of PVCs

**Migration Priority**: **NO** - Use local-path or no persistent storage

---

## Migration Plan

### Phase 1: High Priority (Do First)

1. **swimto PostgreSQL** (10Gi)
   - **Action**: Migrate to Longhorn
   - **Method**: Backup → Create new PVC → Restore
   - **Downtime**: ~15-30 minutes
   - **Risk**: Medium (commercial app, but can be done during maintenance)

### Phase 2: Future Deployments

2. **canopy PostgreSQL** (10Gi)

   - **Action**: Configure for Longhorn from start
   - **Method**: Update StatefulSet volumeClaimTemplate
   - **Downtime**: None (not deployed yet)
   - **Risk**: Low

3. **journey PostgreSQL** (5Gi) - Optional
   - **Action**: Configure for Longhorn when enabled
   - **Method**: Update PVC definition
   - **Downtime**: None (not deployed yet)
   - **Risk**: Low

### Phase 3: Keep As-Is

- **vault**: Keep on local-path
- **observability**: Keep on local-path
- **pihole**: Keep on local-path
- **nima**: Use local-path or no storage

## Storage Summary

| Project    | Current Size | Status   | Recommendation   | Priority |
| ---------- | ------------ | -------- | ---------------- | -------- |
| swimto     | 10Gi         | Active   | **Migrate**      | HIGH     |
| canopy     | 10Gi         | Disabled | **Use Longhorn** | N/A      |
| journey    | 5Gi          | Disabled | **Use Longhorn** | LOW      |
| vault      | 10Gi         | Active   | Keep local-path  | NO       |
| prometheus | 8Gi          | Active   | Keep local-path  | NO       |
| grafana    | 2Gi          | Active   | Keep local-path  | NO       |
| pihole     | 2Gi          | Active   | Keep local-path  | NO       |
| nima       | 6Gi          | Disabled | Keep local-path  | NO       |

## Total Storage Impact

- **To Migrate**: 10Gi (swimto) + 10Gi (canopy when enabled) = 20Gi
- **Keep on local-path**: 22Gi (vault, monitoring, pihole)
- **Future with Longhorn**: 25Gi (swimto + canopy + journey)

## Benefits of Migration

### For swimto:

- ✅ Data survives single node failure
- ✅ Snapshots for point-in-time recovery
- ✅ Backups to external storage (SanDisk SD)
- ✅ Volume can move between nodes
- ✅ Better for commercial application

### For canopy (when enabled):

- ✅ Financial data protection
- ✅ Redundancy from day one
- ✅ No migration needed later

## Migration Risks

### swimto Migration:

- **Risk**: Medium
- **Mitigation**:
  - Backup database before migration
  - Test restore procedure first
  - Schedule during maintenance window
  - Have rollback plan ready

## Next Steps

1. **Immediate**: Review this assessment
2. **Plan**: Schedule swimto migration during maintenance window
3. **Prepare**: Test backup/restore procedure
4. **Execute**: Migrate swimto to Longhorn
5. **Future**: Configure canopy for Longhorn when enabling

## Migration Guide

See `MIGRATION_GUIDE.md` (to be created) for step-by-step migration instructions.
