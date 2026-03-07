# Eldertree Cluster — Knowledge Base for AI Assistant

This document provides comprehensive infrastructure context for OpenClaw/Elder. Use it to answer questions about the cluster, services, and operations accurately.

---

## Cluster Overview

**Eldertree** is a 3-node HA K3s cluster on Raspberry Pi 5 (8GB, ARM64). All nodes are control-plane + etcd. The cluster survives the loss of any single node.

| Node   | Hostname                 | WiFi IP       | Gigabit IP | Role                         |
| ------ | ------------------------ | ------------- | ---------- | ---------------------------- |
| node-1 | `node-1.eldertree.local` | 192.168.2.101 | 10.0.0.1   | Control Plane + etcd + Vault |
| node-2 | `node-2.eldertree.local` | 192.168.2.102 | 10.0.0.2   | Control Plane + etcd + Vault |
| node-3 | `node-3.eldertree.local` | 192.168.2.103 | 10.0.0.3   | Control Plane + etcd + Vault |

- **kube-vip VIP:** 192.168.2.100 (HA API server)
- **Traefik VIP:** 192.168.2.200 (Ingress)
- **Pi-hole DNS:** 192.168.2.201
- **Kubeconfig:** `~/.kube/config-eldertree`

---

## Network & DNS

- **Local domain:** `*.eldertree.local` → 192.168.2.200 (Traefik)
- **Public domain:** `eldertree.xyz` (Cloudflare)
- **Tailscale:** VPN for remote access; nodes advertise 192.168.2.0/24, 10.42.0.0/16, 10.43.0.0/16

---

## Infrastructure Services

| Service   | URL                          | Namespace     | Notes                                      |
| --------- | ---------------------------- | ------------- | ------------------------------------------ |
| Vault     | https://vault.eldertree.local | vault         | HA Raft, 3 replicas; unseal after restart   |
| Grafana   | https://grafana.eldertree.local | observability | admin creds in Vault                        |
| Prometheus| https://prometheus.eldertree.local | observability |                                            |
| Pi-hole   | https://pihole.eldertree.local | pihole        | DNS 192.168.2.201                          |
| FluxCD    | https://flux.eldertree.local | flux-system   | GitOps, path: clusters/eldertree/           |
| Eldertree Docs | https://docs.eldertree.xyz | eldertree-docs | GitHub Pages                               |

---

## Applications

| App       | Local URL                         | Namespace | Notes                                      |
| --------- | --------------------------------- | --------- | ------------------------------------------ |
| Canopy    | https://canopy.eldertree.local    | canopy    | Personal finance                           |
| SwimTO    | https://swimto.eldertree.local    | swimto    | Toronto pool schedules; public: swimto.eldertree.xyz |
| Journey   | https://journey.eldertree.local   | journey   | Career pathfinder                          |
| NIMA      | https://nima.eldertree.local      | nima      | AI/ML learning                             |
| OpenClaw  | https://openclaw.eldertree.local  | openclaw  | AI assistant; Telegram: @eldertree_assistant_bot |
| Elder     | https://elder.eldertree.local     | openclaw  | AI agent sidecar; Swagger: /docs           |
| Pitanga   | https://pitanga.eldertree.local    | pitanga   | Company site; public: pitanga.cloud         |

---

## OpenClaw & Elder (AI Stack)

### LLM Providers

- **Primary:** Google Gemini 1.5 Flash (cloud, free tier)
- **Fallback 1:** Groq (cloud, free tier)
- **Fallback 2:** Ollama (runs on Mac M4 via Tailscale/LAN; not on Pi)

### Elder Endpoints

- `POST /api/llm/best-answer` — Query Gemini, Groq, Ollama in parallel; judge picks best
- `GET /api/llm/providers` — Provider availability
- `POST /api/memory/store` — Store insight
- `POST /api/memory/recall` — Recall insights
- `POST /api/meta/upgrade` — Trigger image rebuild (approval required)
- `GET /api/meta/version` — Current versions

### Elder Skills (OpenClaw tools)

- `elder_best_answer` — Best-of-three LLM answer
- `elder_llm_providers` — Provider status
- `elder_upgrade` — Trigger upgrade (approval)
- `elder_version` — Version info
- `elder_store_insight` — Store learning
- `elder_recall_insights` — Recall learnings

---

## Vault Secret Paths

### OpenClaw

- `secret/openclaw/telegram` — Bot token
- `secret/openclaw/gemini` — Google AI API key
- `secret/openclaw/groq` — Groq API key
- `secret/openclaw/ollama` — api-key, base-url (Mac)
- `secret/openclaw/gateway` — Gateway auth token
- `secret/openclaw/brave` — Brave Search API key

### Elder

- `secret/elder/github-app` — app-id, installation-id, private-key
- `secret/elder/api-key` — API auth key

### Other Apps

- `secret/canopy/*`, `secret/swimto/*`, `secret/journey/*`, `secret/nima/*`, `secret/pitanga/*`
- `secret/monitoring/grafana` — Grafana admin
- `secret/pi-fleet/pihole/webpassword` — Pi-hole admin

---

## FluxCD GitOps

- **Repo:** https://github.com/raolivei/pi-fleet
- **Branch:** main
- **Path:** clusters/eldertree/
- **Reconcile:** `flux reconcile kustomization flux-system --with-source`

---

## Troubleshooting

| Issue          | Action                                                                 |
| -------------- | ---------------------------------------------------------------------- |
| Vault sealed   | `./scripts/operations/unseal-vault.sh`                                 |
| DNS not resolving | Check Pi-hole: `dig @192.168.2.201 google.com`                      |
| Pods not starting | `kubectl describe pod <pod>`, check resources and image pull       |
| Image pull error | Verify ARM64; check GHCR token                                       |
| Service unreachable | `kubectl get ingress -A`; check Traefik                             |
| FluxCD not syncing | `flux get kustomizations`; check logs                              |

---

## Project Repos (raolivei org)

- **pi-fleet** — Eldertree cluster infrastructure
- **pi-fleet-blog** — Blog about the cluster
- **eldertree-docs** — Runbook/docs site
- **elder** — AI agent (cluster, code, GitHub)
- **canopy** — Personal finance
- **swimTO** — Toronto pool schedules
- **journey** — Career pathfinder
- **nima** — AI/ML learning
- **pitanga** — Company website

---

## Quick Commands

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes
kubectl get pods -A
flux get kustomizations
./scripts/operations/unseal-vault.sh
```
