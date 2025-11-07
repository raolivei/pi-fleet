# Custom Helm Charts

This directory contains custom Helm charts for the pi-fleet cluster.

## Structure

Each subdirectory represents a custom Helm chart:

```
helm/
└── <chart-name>/
    ├── Chart.yaml
    ├── values.yaml
    ├── templates/
    └── ...
```

## Usage

Charts in this directory can be:
- Packaged and deployed directly to the cluster
- Referenced by FluxCD HelmRelease resources
- Stored in a local chart repository

## Creating a New Chart

```bash
cd helm
helm create <chart-name>
```

