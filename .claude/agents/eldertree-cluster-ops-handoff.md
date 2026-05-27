---
name: eldertree-cluster-ops-handoff
description: Continuity agent for eldertree K3s cluster ops, watchdog incidents, and pi-fleet GitOps.
---

# Eldertree cluster ops handoff

## SSH / networking

| Node | WiFi (laptop) | Gigabit (in-cluster) |
|------|---------------|----------------------|
| node-1 | `192.168.2.101` | `10.0.0.1` |
| node-2 | `192.168.2.102` | `10.0.0.2` |
| node-3 | `192.168.2.103` | `10.0.0.3` |

- Key: `~/.ssh/id_ed25519_raolivei`, user `raolivei`
- Kubeconfig: `KUBECONFIG=~/.kube/config-eldertree` (VIP `192.168.2.100:6443`)

## Watchdog checklist (after any hang)

```bash
./pi-fleet/scripts/verify-watchdog.sh
```

Must show: RPI drop-in **absent**, `watchdog` holds `/dev/watchdog`, `alive=/dev/watchdog` in journal.

Ansible (all nodes):

```bash
cd pi-fleet/ansible
ansible-playbook -i inventory/hosts.yml playbooks/setup-hardware-watchdog.yml
```

Forensics: `journalctl --boot=-1` (requires persistent journal — enabled by playbook).

## Known incident docs

- `pi-fleet/docs/NODE-1-HANG-ROOT-CAUSE-2026-05-26.md` — systemd `40-rpi-enable-watchdog.conf`
- `pi-fleet/docs/NODE-1-HANG-2026-05-26-SECOND.md` — second hang, test-binary gap
- `pi-fleet/docs/HARDWARE_WATCHDOG.md` — runbook

## Open / out of scope unless asked

- README PR branches (canopy, swimTO, workspace-config)
- Cloudflare tunnel HTTP 1033 on public sites
- swimto Postgres `local-path` scheduling

## Flux

- App changes: `pi-fleet/clusters/eldertree/`
- Reconcile: `flux reconcile kustomization flux-system --with-source`
