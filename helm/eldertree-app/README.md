# eldertree-app

Shared Helm chart for deploying applications on the Eldertree k3s cluster.

## What it does

Generates Kubernetes resources from a single `values.yaml`:

- **Deployment** + **Service** per component
- **Ingress** with Traefik (TLS, middleware, multi-host, IP-based)
- **Middleware** (redirect-https, basicAuth, replacePathRegex, headers)
- **PersistentVolumeClaim**, **ConfigMap**, **ExternalSecret**

## Built-in defaults

Every component automatically gets:

```yaml
# Pod security
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

# Container security
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]

# Cluster config
nodeSelector:
  kubernetes.io/arch: arm64
imagePullSecrets:
  - name: ghcr-secret
```

Override per component with `podSecurityContext:` / `securityContext:`.
Skip defaults for built-in images (postgres, redis) with `builtinImage: true`.

## Usage

Each app creates a `helmrelease.yaml` in its cluster directory:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: myapp
  namespace: myapp
spec:
  chart:
    spec:
      chart: ./helm/eldertree-app
      version: "0.1.1"
      sourceRef:
        kind: GitRepository
        name: flux-system
        namespace: flux-system
  values:
    components:
      myapp-api:
        image:
          repository: ghcr.io/raolivei/myapp-api
          tag: v1.0.0  # {"$imagepolicy": "myapp:myapp-api-policy:tag"}
        port: 8000
        probes:
          path: /health

      myapp-frontend:
        image:
          repository: ghcr.io/raolivei/myapp-frontend
          tag: v1.0.0
        port: 3000

    ingress:
      myapp:
        host: myapp.eldertree.local
        service: myapp-frontend
        port: 3000
        tls:
          secretName: myapp-tls
          certManager: true
        paths:
          - path: /api
            service: myapp-api
            port: 8000
```

## Component fields

| Field | Default | Description |
|-------|---------|-------------|
| `image.repository` | *required* | Container image |
| `image.tag` | *required* | Image tag |
| `image.pullPolicy` | — | IfNotPresent, Always |
| `replicas` | 1 | Pod replicas |
| `port` | 8000 | Container port |
| `servicePort` | = port | Service port (if different) |
| `env` | [] | Environment variables |
| `envFrom` | [] | ConfigMap/Secret refs |
| `command` / `args` | — | Override entrypoint |
| `resources` | — | CPU/memory requests and limits |
| `probes.path` | /health | HTTP probe path |
| `probesEnabled` | true | Set false to skip probes |
| `builtinImage` | false | Skip imagePullSecrets/securityContext |
| `serviceAccountName` | — | Service account |
| `strategy` | — | Recreate or RollingUpdate |
| `volumes` / `volumeMounts` | — | Extra volumes |
| `podSecurityContext` | global | Override pod security |
| `securityContext` | global | Override container security |

## What stays outside the chart

These resources are kept as standalone YAML (not in the HelmRelease):

| Resource | Reason |
|----------|--------|
| ExternalSecrets | Avoids prune race conditions |
| StatefulSets | volumeClaimTemplates |
| Redis with sidecars | Complex init containers |
| CronJobs | Different lifecycle |
| RBAC | Cluster-scoped resources |
| Image automation | FluxCD requirement |

## Apps using this chart

| App | Namespace | Components |
|-----|-----------|------------|
| pitanga | pitanga | website, northwaysignal |
| canopy | canopy | api, frontend, redis |
| swimto | swimto | api, web |
| openclaw | openclaw | gateway, grove |
| nima | nima | api, frontend (disabled) |
| journey | journey | api, frontend |

## Development

```bash
# Render templates locally
helm template myapp ./helm/eldertree-app --namespace myapp -f values.yaml

# Validate
helm lint ./helm/eldertree-app -f values.yaml
```
