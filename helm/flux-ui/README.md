# Flux UI Helm Chart

Flux UI Helm chart for visualizing and managing FluxCD deployments using Weave GitOps.

## Overview

This chart structure is prepared for deploying Weave GitOps, which provides a web-based UI for managing FluxCD resources including:
- GitRepositories
- HelmRepositories
- Kustomizations
- HelmReleases
- Buckets
- And other FluxCD CRDs

## Current Deployment

Currently, Weave GitOps is deployed directly via HelmRelease referencing the HelmRepository (see `clusters/eldertree/observability/flux-ui-helmrelease.yaml`). This chart structure is maintained for future use when wrapping as a dependency becomes available.

## Configuration

### Ingress

The deployment configures Traefik ingress with TLS certificates via cert-manager.

Default host: `flux-ui.eldertree.local`

### Resources

Default resource limits are optimized for Raspberry Pi:
- CPU: 100m request, 500m limit
- Memory: 128Mi request, 512Mi limit

### RBAC

Weave GitOps requires cluster-admin permissions to manage FluxCD resources. The deployment creates the necessary RBAC resources.

## Access

After deployment, access the UI at:
- URL: `https://flux-ui.eldertree.local` (via ingress)
- Or port-forward: `kubectl port-forward -n observability svc/weave-gitops 9001:9001`

## Dependencies

- Weave GitOps Helm chart (via HelmRepository)
- FluxCD installed in cluster
- Traefik ingress controller
- cert-manager for TLS certificates

## Notes

- Helm v4 compatible
- Tested on K3s v1.33.5+k3s1
- Optimized for Raspberry Pi 5 (ARM64)
- Chart structure ready for future dependency wrapping

