# Helm v4 Compatibility Report

**Generated**: November 13, 2025  
**Helm v4 Release**: [v4.0.0](https://github.com/helm/helm/releases/tag/v4.0.0)

## Summary

✅ **Your Helm charts are compatible with Helm v4!**

Both custom charts in this repository follow Helm v3 best practices and use features that are fully supported in Helm v4.

## Charts Analyzed

1. **cert-manager-issuers** (v0.1.0)
2. **monitoring-stack** (v0.1.0)

---

## Compatibility Analysis

### ✅ Chart API Version

Both charts use `apiVersion: v2`, which is **fully supported** in Helm v4:

```yaml
# cert-manager-issuers/Chart.yaml
apiVersion: v2

# monitoring-stack/Chart.yaml
apiVersion: v2
```

**Status**: ✅ No action required. Helm v4 continues to support Chart API v2.

---

### ✅ Chart Dependencies

Your charts use standard dependency declarations that work in v4:

**cert-manager-issuers**:

```yaml
dependencies:
  - name: cert-manager
    version: ">=1.0.0"
    repository: https://charts.jetstack.io
    condition: cert-manager.enabled
```

**monitoring-stack**:

```yaml
dependencies:
  - name: prometheus
    version: "25.30.1"
    repository: https://prometheus-community.github.io/helm-charts
    condition: prometheus.enabled
  - name: grafana
    version: "8.8.2"
    repository: https://grafana.github.io/helm-charts
    condition: grafana.enabled
```

**Status**: ✅ Standard dependency syntax is unchanged in v4.

---

### ✅ Templates and Templating

Your templates use standard Helm templating features:

- Conditional rendering (`{{- if .Values.* }}`)
- Value substitution (`{{ .Values.* }}`)
- Standard Kubernetes resources (ClusterIssuer, Namespace)

**Status**: ✅ No breaking changes to template functions or syntax.

---

### ✅ FluxCD Integration

Your charts are deployed via FluxCD HelmRelease resources, which isolate you from direct Helm CLI changes:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
spec:
  chart:
    spec:
      chart: ./pi-fleet/helm/cert-manager-issuers
```

**Status**: ✅ FluxCD v2 will handle Helm v4 compatibility. Your HelmRelease definitions remain unchanged.

---

### ℹ️ Features Not Used (No Impact)

The following Helm v4 features are not currently used in your charts:

- ❌ **Post-renderers**: Not used (no action needed)
- ❌ **Plugins**: Not used (no action needed)
- ❌ **Direct CLI usage**: Charts managed via FluxCD (no action needed)

---

## Key Helm v4 Changes (For Reference)

### Breaking Changes

1. **CLI Flags and Output**: Some flags and output formats changed

   - **Impact**: None (using FluxCD, not direct CLI)

2. **Plugin System Redesigned**: Now supports WebAssembly

   - **Impact**: None (no custom plugins)

3. **Post-renderers are now plugins**: If you were using post-renderers
   - **Impact**: None (not using post-renderers)

### New Features You Can Leverage

1. **Server-side Apply**: More robust resource management

   - Can be enabled via FluxCD HelmRelease:

   ```yaml
   spec:
     install:
       createNamespace: true
       remediation:
         retries: 3
     # Future: Add serverSideApply when FluxCD supports it
   ```

2. **Improved Resource Watching**: Better wait/rollout behavior

   - Automatically benefits your deployments

3. **Content-based Caching**: Faster chart operations

   - Automatic performance improvement

4. **Reproducible Builds**: Chart archives are deterministic
   - Benefits CI/CD if you package charts

---

## Recommendations

### Immediate Actions

✅ **None required** - Your charts are compatible as-is.

### Future Enhancements

When you're ready to upgrade to Helm v4, consider:

1. **Review FluxCD Helm Controller Updates**

   - FluxCD will release updates to support Helm v4
   - Monitor: https://github.com/fluxcd/helm-controller

2. **Test Chart Upgrades**

   - Test in a non-production cluster first
   - Validate that chart installations/upgrades work as expected

3. **Leverage Server-side Apply**

   - When FluxCD supports it, enable for better resource management
   - Particularly useful for CRDs and complex resources

4. **Update Documentation**
   - If you add any Helm v4-specific features
   - Update chart READMEs with minimum version requirements

---

## Testing Strategy

When FluxCD supports Helm v4, test with:

```bash
# 1. Validate chart syntax (local testing)
helm lint pi-fleet/helm/cert-manager-issuers
helm lint pi-fleet/helm/monitoring-stack

# 2. Template rendering (verify output)
helm template cert-manager-issuers pi-fleet/helm/cert-manager-issuers
helm template monitoring-stack pi-fleet/helm/monitoring-stack

# 3. Dry-run install (if testing directly)
helm install --dry-run --debug cert-manager-issuers pi-fleet/helm/cert-manager-issuers

# 4. Let FluxCD handle actual deployment
kubectl apply -f clusters/eldertree/infrastructure/issuers/helmrelease.yaml
kubectl apply -f clusters/eldertree/monitoring/helmrelease.yaml
```

---

## Migration Timeline

### Now (Helm v3)

- ✅ All charts compatible
- ✅ No changes needed

### When FluxCD Supports Helm v4

1. Review FluxCD release notes
2. Test in dev/staging environment
3. Update FluxCD Helm Controller
4. Monitor chart deployments
5. Enjoy improved performance and features

### Future (Optional)

- Explore new Helm v4 Chart API v3 (when released)
- Consider server-side apply for specific use cases
- Evaluate WebAssembly plugins if needed

---

## Resources

- [Helm v4.0.0 Release Notes](https://github.com/helm/helm/releases/tag/v4.0.0)
- [Helm v4 Documentation](https://helm.sh/docs/overview/)
- [FluxCD Helm Controller](https://github.com/fluxcd/helm-controller)
- [Chart API v2 Specification](https://helm.sh/docs/topics/charts/)

---

## Questions?

If you have specific concerns about Helm v4 compatibility:

1. Check FluxCD compatibility: https://fluxcd.io/
2. Review chart-specific issues: https://github.com/helm/helm/issues
3. Test in isolated environment before production upgrade

---

**Conclusion**: Your charts are ready for Helm v4. The FluxCD GitOps approach provides a clean separation between chart definitions and deployment tooling, making this transition seamless.
