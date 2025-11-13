# cert-manager-issuers

Custom Helm chart for managing cert-manager ClusterIssuers in pi-fleet.

## Features

- Self-signed ClusterIssuer (default)
- ACME Let's Encrypt issuer (optional)

## Values

```yaml
selfSigned:
  enabled: true
  name: selfsigned-cluster-issuer

acme:
  enabled: false
  email: ""
  server: https://acme-v02.api.letsencrypt.org/directory
  name: letsencrypt-prod
```

## Usage

Deploy via FluxCD HelmRelease:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cert-manager-issuers
spec:
  chart:
    spec:
      chart: ./helm/cert-manager-issuers
      sourceRef:
        kind: GitRepository
        name: flux-system
```
