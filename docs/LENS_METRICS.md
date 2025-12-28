# Configuring Prometheus Metrics in Lens

To see cluster metrics (CPU, Memory, Network, etc.) directly in Lens for the `eldertree` cluster, follow these steps:

## 1. Open Cluster Settings

- Open Lens on your desktop.
- Right-click on the **eldertree** cluster in the left sidebar.
- Select **Settings**.

## 2. Configure Metrics Provider

- In the Settings menu, navigate to **Metrics**.
- From the **Prometheus** dropdown, ensure **Prometheus** is selected as the provider.

## 3. Specify Prometheus Service

- In the **Prometheus Service Address** field, enter:

  ```text
  observability/observability-monitoring-stack-prometheus-server:80
  ```

- This follows the format `namespace/service-name:port`.

## 4. Verify

- Close the settings.
- Navigate to the **Nodes** or **Workloads** view.
- You should now see sparklines and graphs for resource usage.

## Troubleshooting

- **No metrics showing**: Ensure your `kubectl` context is correctly set to `eldertree` and you can reach the cluster.
- **Service Name**: If you renamed the monitoring stack, verify the service name with:

  ```bash
  kubectl get svc -n observability | grep prometheus-server
  ```

- **RBAC**: Lens needs permissions to read metrics. If you are using an admin account (which is standard for `eldertree`), this shouldn't be an issue.
