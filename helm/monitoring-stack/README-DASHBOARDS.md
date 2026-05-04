# Dashboard Management Guide

This guide explains how to manage Grafana dashboards using this Helm chart.

## Overview

All Grafana dashboards are managed as Infrastructure-as-Code using:
- **Dashboard JSON files** in the [`dashboards/`](dashboards/) directory
- **Folder mappings** in [`values.yaml`](values.yaml) under `dashboardFolders`
- **Helm templates** that generate ConfigMaps with folder annotations
- **Grafana sidecar** that discovers and provisions dashboards automatically

## Folder Structure

Dashboards are organized into two top-level categories:

### Applications/
Product-specific dashboards for deployed applications.

- `Applications/Visage` - Visage ML training and operations
- `Applications/SwimTO` - SwimTO application
- `Applications/Pitanga` - Pitanga application

### Platform/
Infrastructure and cluster-level dashboards.

- `Platform/Overview` - High-level cluster dashboards
- `Platform/Cluster` - Kubernetes cluster metrics
- `Platform/Workloads` - Deployment and pod monitoring
- `Platform/Capacity` - Resource usage by namespace
- `Platform/Network` - Traefik and network intelligence
- `Platform/Hardware` - Raspberry Pi hardware health
- `Platform/Security` - Vault and security monitoring

## Adding a New Dashboard

### Step 1: Create Dashboard JSON

1. Create your dashboard in the Grafana UI or export an existing one
2. Save the JSON file to `dashboards/my-dashboard.json`
3. Ensure the dashboard has these required fields:
   ```json
   {
     "uid": "my-dashboard",
     "title": "My Dashboard Title",
     "tags": ["relevant", "tags", "here"],
     ...
   }
   ```

**Best practices:**
- Set `uid` to match the filename (without `.json`)
- Include descriptive `tags` for searchability
- Add `eldertree` tag for cluster-specific dashboards

### Step 2: Add Folder Mapping

Edit [`values.yaml`](values.yaml) and add your dashboard to the `dashboardFolders` map (around line 323):

```yaml
dashboardFolders:
  # ... existing mappings ...
  my-dashboard: "Applications/MyApp"  # or "Platform/SubCategory"
```

**Folder naming convention:**
- Format: `Category/Subcategory`
- Categories: `Applications` or `Platform`
- Subcategory: App name or platform area
- If no mapping exists, defaults to `"Platform"`

### Step 3: Validate

Run the validation script to check your changes:

```bash
./scripts/validate-dashboards.sh
```

This checks:
- JSON syntax validity
- Required fields (`uid`, `title`, `tags`)
- Folder mapping exists in `values.yaml`
- UID/filename consistency (warning only)

### Step 4: Deploy

Deploy the updated Helm chart:

```bash
# Test rendering first
helm template . | grep -A 10 "kind: ConfigMap"

# Deploy to cluster
helm upgrade monitoring-stack . -n observability
```

The Grafana sidecar will automatically discover and provision the new dashboard within minutes.

## Editing Existing Dashboards

### Option 1: Edit in Grafana UI (Recommended for Quick Changes)

1. Make changes in Grafana UI
2. Export the dashboard JSON (Share → Export → Save to file)
3. Replace the file in `dashboards/`
4. Commit to git
5. Redeploy Helm chart

**Note:** Changes made only in the Grafana UI are ephemeral and will be lost on pod restart unless exported back to git.

### Option 2: Edit JSON Directly

1. Edit `dashboards/my-dashboard.json`
2. Validate with `./scripts/validate-dashboards.sh`
3. Deploy Helm chart
4. Verify in Grafana UI

## Changing Dashboard Folders

To move a dashboard to a different folder:

1. Edit the folder mapping in `values.yaml`:
   ```yaml
   dashboardFolders:
     my-dashboard: "Platform/NewCategory"  # Changed from old category
   ```

2. Deploy the updated chart:
   ```bash
   helm upgrade monitoring-stack . -n observability
   ```

The sidecar will update the dashboard's folder automatically.

## Removing a Dashboard

1. Delete the JSON file from `dashboards/`
2. Remove the mapping from `values.yaml` `dashboardFolders`
3. Deploy the chart

The corresponding ConfigMap will be removed and Grafana will delete the dashboard.

## How It Works

### 1. Dashboard Files → ConfigMaps

The Helm template [`templates/dashboards.yaml`](templates/dashboards.yaml) globs all `*.json` files in the `dashboards/` directory:

```yaml
{{- range $path, $_ := .Files.Glob "dashboards/*.json" }}
{{- $name := base $path }}
{{- $base := $name | replace ".json" "" }}
{{- $foldermap := $.Values.grafana.dashboardFolders | default dict }}
{{- $folder := index $foldermap $base | default "Platform" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: dashboard-{{ $base }}
  labels:
    grafana_dashboard: "1"
  annotations:
    grafana_folder: {{ $folder | quote }}
data:
  {{ $name }}: |
{{ $.Files.Get $path | indent 4 }}
{{- end }}
```

For each dashboard:
- Extracts filename (e.g., `visage-operations.json`)
- Removes `.json` extension to get basename (`visage-operations`)
- Looks up folder in `dashboardFolders` map
- Defaults to `"Platform"` if no mapping found
- Creates ConfigMap with:
  - Label: `grafana_dashboard: "1"`
  - Annotation: `grafana_folder: "<folder_path>"`
  - Data: Dashboard JSON content

### 2. Grafana Sidecar Discovery

The Grafana sidecar (configured in `values.yaml` lines 338-346) watches for ConfigMaps:

```yaml
sidecar:
  dashboards:
    enabled: true
    label: grafana_dashboard
    labelValue: "1"
    searchNamespace: observability
    folderAnnotation: grafana_folder
    provider:
      foldersFromFilesStructure: true
```

It:
- Watches namespace `observability` for ConfigMaps with label `grafana_dashboard: "1"`
- Reads the `grafana_folder` annotation
- Provisions the dashboard into the specified folder
- Creates folder hierarchy automatically (e.g., `Applications/Visage`)

### 3. Dashboard URL Pattern

Dashboards are accessible at:
```
https://grafana.eldertree.local/d/<uid>/<optional-slug>
```

Example:
- `https://grafana.eldertree.local/d/visage-ops`
- `https://grafana.eldertree.local/d/eldertree-command-center`

## Troubleshooting

### Dashboard not appearing in Grafana

1. Check if ConfigMap was created:
   ```bash
   kubectl get configmap -n observability -l grafana_dashboard=1
   ```

2. Check ConfigMap has correct annotation:
   ```bash
   kubectl get configmap dashboard-my-dashboard -n observability -o yaml | grep grafana_folder
   ```

3. Check Grafana sidecar logs:
   ```bash
   kubectl logs -n observability deployment/monitoring-stack-grafana -c grafana-sc-dashboard
   ```

4. Verify sidecar is watching the right namespace:
   ```bash
   helm get values monitoring-stack -n observability | grep -A 10 "sidecar:"
   ```

### Dashboard appears but in wrong folder

1. Check folder mapping in `values.yaml`:
   ```bash
   grep "my-dashboard:" values.yaml
   ```

2. Check ConfigMap annotation:
   ```bash
   kubectl get configmap dashboard-my-dashboard -n observability -o jsonpath='{.metadata.annotations.grafana_folder}'
   ```

3. Update the mapping and redeploy if needed

### Changes not taking effect

1. Confirm Helm release was updated:
   ```bash
   helm history monitoring-stack -n observability
   ```

2. Force ConfigMap refresh:
   ```bash
   kubectl delete configmap dashboard-my-dashboard -n observability
   helm upgrade monitoring-stack . -n observability
   ```

3. Restart Grafana pod if needed:
   ```bash
   kubectl rollout restart deployment/monitoring-stack-grafana -n observability
   ```

### JSON syntax errors

Run the validation script:
```bash
./scripts/validate-dashboards.sh
```

Common issues:
- Unescaped quotes in panel titles or queries
- Trailing commas
- Missing required fields (`uid`, `title`)

## Validation Script

The validation script [`scripts/validate-dashboards.sh`](scripts/validate-dashboards.sh) checks:

- ✅ JSON syntax validity
- ✅ Required fields present (`uid`, `title`)
- ⚠️  Tags present (warning if missing)
- ✅ Folder mapping exists in `values.yaml`
- ⚠️  UID matches basename (warning if mismatch)

**Exit codes:**
- `0` - All validations passed
- `1` - Errors found (invalid JSON, missing required fields)

**Usage:**
```bash
# Validate all dashboards
./scripts/validate-dashboards.sh

# Run in CI/CD before deployment
./scripts/validate-dashboards.sh || exit 1
```

## Disaster Recovery

All dashboards are fully reconstructible from git:

1. Clone repository
2. Deploy Helm chart:
   ```bash
   helm install monitoring-stack . -n observability
   ```
3. All dashboards will be provisioned automatically

**Source of truth:** Dashboard JSON files in `dashboards/` + folder mappings in `values.yaml`

## Migration from Static Provisioning

**Previous system (deprecated):** Static file provisioning via `provisioning/dashboards/dashboards.yml`

**Current system:** Helm-managed with sidecar discovery

To migrate dashboards:
1. Copy JSON files to `dashboards/` directory
2. Add folder mappings to `values.yaml` `dashboardFolders`
3. Deploy Helm chart
4. Verify dashboards appear in Grafana
5. Remove old provisioning files

See [`visage/monitoring/grafana/README-MIGRATION.md`](../../visage/monitoring/grafana/README-MIGRATION.md) for the Visage migration example.

## Best Practices

1. **Use git as source of truth** - Always export changes from Grafana UI back to git
2. **Validate before deploying** - Run `./scripts/validate-dashboards.sh`
3. **Use consistent naming**:
   - Filename: `my-dashboard.json` (kebab-case)
   - UID: `my-dashboard` (matches filename)
   - Title: "My Dashboard" (human-readable)
4. **Add descriptive tags** - Makes dashboards discoverable
5. **Choose appropriate folders**:
   - `Applications/*` for product/app-specific dashboards
   - `Platform/*` for infrastructure/cluster dashboards
6. **Test in staging first** - Verify dashboards work before deploying to production
7. **Keep dashboards focused** - One dashboard per app/area, don't create mega-dashboards
8. **Document custom metrics** - Add comments in dashboard JSON or panel descriptions

## See Also

- [DASHBOARDS.md](DASHBOARDS.md) - Complete dashboard inventory and PromQL examples
- [values.yaml](values.yaml) - Helm configuration including folder mappings
- [templates/dashboards.yaml](templates/dashboards.yaml) - ConfigMap generation template
- [scripts/validate-dashboards.sh](scripts/validate-dashboards.sh) - Validation script

## Questions?

Check existing dashboards in `dashboards/` for examples, or see [DASHBOARDS.md](DASHBOARDS.md) for the complete inventory.
