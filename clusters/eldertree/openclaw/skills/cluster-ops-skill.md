# Cluster Ops Skill

Monitor and interact with the eldertree Kubernetes cluster.
kubectl runs in the OpenClaw pod; permissions follow the `openclaw` Kubernetes RBAC (see pi-fleet `openclaw/rbac.yaml`).

## OpenClaw container (eldertree)

- **Do not run `openclaw update` or `openclaw` CLI** in this pod — the binary is not a supported admin path. To upgrade OpenClaw, trigger the **GitHub Action** that builds `ghcr.io/raolivei/openclaw` and let **Flux** roll the new image (or use Elder `elder_upgrade` if configured).
- **Gateway Web UI** uses **token** auth: paste the gateway token from Vault `secret/openclaw/gateway` (property `token` → k8s `OPENCLAW_GATEWAY_TOKEN`) when the Control UI asks; internal tools use the same value via env.

## How to Use

You can run kubectl commands using the shell tool. Common commands:

### List pods in a namespace
```bash
kubectl get pods -n swimto
kubectl get pods -n canopy
kubectl get pods -n openclaw
kubectl get pods -A  # all namespaces
```

### Get pod logs
```bash
kubectl logs -n swimto deployment/swimto-api --tail=50
kubectl logs -n swimto deployment/swimto-web --tail=50
kubectl logs -n canopy deployment/canopy-api --tail=50
```

### Check pod details (for troubleshooting)
```bash
kubectl describe pod -n swimto -l app=swimto-api
kubectl get events -n swimto --sort-by='.lastTimestamp'
```

### Cluster health
```bash
kubectl get nodes
kubectl top nodes  # resource usage
kubectl top pods -n swimto  # pod resource usage
```

### Services and ingress
```bash
kubectl get svc -n swimto
kubectl get ingress -n swimto
```

## HashiCorp Vault

Vault is deployed in the `vault` namespace.
Internal API: `http://vault.vault.svc.cluster.local:8200`

Check health (via exec):
```bash
curl -s http://vault.vault.svc.cluster.local:8200/v1/sys/health | head -c 200
```

Check seal status:
```bash
curl -s http://vault.vault.svc.cluster.local:8200/v1/sys/seal-status
```

For secret retrieval, use Elder's API — Elder handles the Vault token internally.
Do NOT try to read Vault secrets directly with exec; Elder's skill endpoints
(elder_*, gmail_*) already have the token and handle auth.

## Namespaces in Eldertree

- **swimto**: SwimTO pool schedule app (Rafa's project)
- **canopy**: Personal finance dashboard
- **openclaw**: This is where you (Elder) live!
- **vault**: HashiCorp Vault for secrets (`http://vault.vault.svc.cluster.local:8200`)
- **monitoring**: Prometheus + Grafana
- **longhorn-system**: Distributed storage
- **flux-system**: GitOps controller

## Example Conversations

User: "Show me swimto pod logs"
Assistant: *runs `kubectl logs -n swimto deployment/swimto-api --tail=100`*

User: "Are all pods healthy in swimto?"
Assistant: *runs `kubectl get pods -n swimto` and analyzes output*

User: "What's using the most memory?"
Assistant: *runs `kubectl top pods -A --sort-by=memory`*

### Check for recent issues (last 24h)
```bash
# Get recent events across all namespaces (warnings and errors)
kubectl get events -A --sort-by='.lastTimestamp' | grep -E "Warning|Error" | tail -30

# Get events for a specific namespace
kubectl get events -n swimto --sort-by='.lastTimestamp'

# Check for pod restarts (indicates issues)
kubectl get pods -A | grep -E "CrashLoopBackOff|Error|Pending|ImagePullBackOff"

# Check node status
kubectl get nodes
kubectl describe nodes | grep -A 5 "Conditions:"
```

## Important Notes

- You have READ-ONLY access (no delete, scale, or modify operations)
- Always use `--tail=N` when getting logs to avoid overwhelming output
- Check events if pods are not starting: `kubectl get events -n NAMESPACE`
- DO NOT try to access system logs (journalctl, /var/log) - use kubectl events instead
- For "any issues" questions, check: events, pod status, node status
