# Node scheduling tiers

node-1 has had intermittent freezes. **App workloads are deprioritized on node-1** automatically — no manual `kubectl` steps.

## Policy (declared in Git)

| Node | Label `eldertree.xyz/node-tier` | Taint |
|------|----------------------------------|-------|
| node-1 | `unstable` | `eldertree.xyz/prefer-stable-nodes=true:PreferNoSchedule` |
| node-2, node-3 | `stable` | none |

**Unchanged on purpose:** etcd, control-plane, DaemonSets, and PVC-bound pods (e.g. `vault-1` on node-1).

## How it is enforced (automatic)

| Layer | What runs |
|-------|-----------|
| **Flux** | [`node-scheduling/reconciler-cronjob.yaml`](../clusters/eldertree/core-infrastructure/node-scheduling/reconciler-cronjob.yaml) every 15m — reapplies labels/taints |
| **k3s install** | Per-node `node_k3s_server_args` in [`ansible/inventory/host_vars/`](../ansible/inventory/host_vars/) on **new** installs |
| **Ansible** | [`configure-node-scheduling-tiers.yml`](../ansible/playbooks/configure-node-scheduling-tiers.yml) from `setup-cluster`, `install-k3s`, `setup-hardware-watchdog` |
| **Helm** | `eldertree-app` global `nodeAffinity` prefers `node-tier != unstable` |
| **Vault CronJob** | `nodeSelector: eldertree.xyz/node-tier: stable` |

## Verify (read-only)

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes -L eldertree.xyz/node-tier
kubectl get cronjob -n kube-system node-scheduling-tier-reconciler
```

## Incident: cordon only

If node-1 is actively failing, cordon is still the right **temporary** brake (not stored in Git):

```bash
kubectl cordon node-1.eldertree.local
kubectl uncordon node-1.eldertree.local   # after recovery
```

Flux reconciler will **not** remove `cordon` — that remains a deliberate operator action.

## Change policy

Edit host vars + reconciler CronJob script + `ansible/group_vars/all.yml`, commit, merge — Flux and the next Ansible run apply it.
