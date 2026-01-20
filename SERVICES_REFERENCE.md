# Eldertree Cluster - Services Reference

**Quick reference for all services, IPs, URLs, and credentials in the eldertree Kubernetes cluster.**

**Last Updated:** January 19, 2026  
**Cluster:** eldertree (Raspberry Pi 5 k3s cluster)

---

## 📡 Network Infrastructure

### Cluster Nodes (3-Node HA Control Plane)

| Node   | Hostname                 | IP (wlan0)      | IP (eth0)  | Role                         |
| ------ | ------------------------ | --------------- | ---------- | ---------------------------- |
| node-1 | `node-1.eldertree.local` | `192.168.2.101` | `10.0.0.1` | Control Plane + etcd + Vault |
| node-2 | `node-2.eldertree.local` | `192.168.2.102` | `10.0.0.2` | Control Plane + etcd + Vault |
| node-3 | `node-3.eldertree.local` | `192.168.2.103` | `10.0.0.3` | Control Plane + etcd + Vault |

**High Availability:** All 3 nodes are control-plane nodes. The cluster can survive the loss of ANY single node.

- **kube-vip VIP:** `192.168.2.100` (API server failover)
- **Failure Tolerance:** 1 node (etcd quorum: 2/3)

### DNS Server

- **Pi-hole DNS:** `192.168.2.201` (kube-vip LoadBalancer)
- **Router DNS:** Configure router to use `192.168.2.201` as primary DNS
- **Local Domain:** `*.eldertree.local` resolves to `192.168.2.200` (Traefik ingress)

### LoadBalancer Access

kube-vip handles both control plane VIP (192.168.2.100) and service LoadBalancer IPs.
This replaced MetalLB and provides reliable ARP-based IP assignment that works with all routers.

**Direct LoadBalancer Access:**

```bash
# Traefik ingress
curl -k https://192.168.2.200 -H 'Host: vault.eldertree.local'

# Pi-hole DNS
dig @192.168.2.201 grafana.eldertree.local
```

**Alternative Access Methods:**

1. **NodePort** (if LoadBalancer not working):

   ```bash
   curl -k https://192.168.2.101:32474 -H 'Host: vault.eldertree.local'
   ```

2. **Port Forward** (for individual services):

   ```bash
   kubectl port-forward -n vault svc/vault 8200:8200
   ```

### Kubernetes API

- **Control Plane IP:** `192.168.2.101` (or `10.0.0.1` on gigabit network)
- **Kubeconfig:** `~/.kube/config-eldertree`
- **API Endpoint:** `https://192.168.2.101:6443` (or via kubeconfig)

---

## 🔧 Infrastructure Services

### Vault (Secrets Management) - HA Mode

| Property          | Value                                                                          |
| ----------------- | ------------------------------------------------------------------------------ |
| **Local URL**     | `https://vault.eldertree.local`                                                |
| **Namespace**     | `vault`                                                                        |
| **Mode**          | **HA with Raft** (3 replicas, 1 leader + 2 standbys)                           |
| **Storage**       | Longhorn (replicated across all nodes)                                         |
| **Port Forward**  | `kubectl port-forward -n vault svc/vault 8200:8200` → `https://localhost:8200` |
| **Credentials**   | Root token stored in K8s secret `vault-unseal-keys` and password manager       |
| **Unseal Keys**   | 5 keys (need 3 to unseal) - stored in K8s secret for auto-unseal               |
| **Unseal Script** | `./scripts/operations/unseal-vault.sh` (unseals all 3 pods automatically)      |
| **Init Script**   | `./scripts/operations/init-vault-ha.sh` (for fresh cluster initialization)     |
| **Status Check**  | `kubectl exec -n vault vault-0 -- vault status`                                |
| **Raft Peers**    | `kubectl exec -n vault vault-0 -- vault operator raft list-peers`              |

**HA Failover:** If the leader pod fails, a standby is automatically promoted to leader within seconds.

**⚠️ Important:** After node restarts, run `./scripts/operations/unseal-vault.sh` to unseal all pods.

### Grafana (Monitoring Dashboards)

| Property                | Value                                                          |
| ----------------------- | -------------------------------------------------------------- |
| **Local URL**           | `https://grafana.eldertree.local`                              |
| **Namespace**           | `observability`                                                |
| **Username**            | `admin`                                                        |
| **Password**            | Stored in Vault: `secret/monitoring/grafana` → `adminPassword` |
| **How to Get Password** | See "Getting Credentials" section below                        |

### Prometheus (Metrics)

| Property           | Value                                |
| ------------------ | ------------------------------------ |
| **Local URL**      | `https://prometheus.eldertree.local` |
| **Namespace**      | `observability`                      |
| **Authentication** | None (internal only)                 |

### Pi-hole (DNS & Ad Blocking)

| Property                | Value                                                 |
| ----------------------- | ----------------------------------------------------- |
| **Local URL**           | `https://pihole.eldertree.local/admin/`               |
| **DNS IP**              | `192.168.2.201` (port 53)                             |
| **Namespace**           | `pihole`                                              |
| **Password**            | Stored in Vault: `secret/pi-fleet/pihole/webpassword` |
| **How to Get Password** | See "Getting Credentials" section below               |

### FluxCD (GitOps UI)

| Property           | Value                                           |
| ------------------ | ----------------------------------------------- |
| **Local URL**      | `https://flux-ui.eldertree.local` (if deployed) |
| **Namespace**      | `flux-system`                                   |
| **Git Repository** | `https://github.com/raolivei/pi-fleet`          |
| **Branch**         | `main`                                          |
| **Path**           | `clusters/eldertree/`                           |

### Eldertree Docs

| Property       | Value                                       |
| -------------- | ------------------------------------------- |
| **Public URL** | `https://docs.eldertree.xyz` (GitHub Pages) |
| **Local URL**  | `https://docs.eldertree.local`              |
| **Namespace**  | `eldertree-docs`                            |

---

## 📱 Applications

### Canopy (Personal Finance)

| Property          | Value                                |
| ----------------- | ------------------------------------ |
| **Local URL**     | `https://canopy.eldertree.local`     |
| **API URL**       | `https://canopy.eldertree.local/api` |
| **Namespace**     | `canopy`                             |
| **Frontend Port** | 3000                                 |
| **API Port**      | 8000                                 |
| **Database**      | PostgreSQL (in cluster)              |
| **Credentials**   | Stored in Vault: `secret/canopy/*`   |

### SwimTO (Toronto Pool Schedules)

| Property          | Value                                                                      |
| ----------------- | -------------------------------------------------------------------------- |
| **Local URL**     | `https://swimto.eldertree.local`                                           |
| **Public URL**    | `https://swimto.eldertree.xyz` (via Cloudflare Tunnel)                     |
| **API URL**       | `https://swimto.eldertree.local/api` or `https://swimto.eldertree.xyz/api` |
| **Namespace**     | `swimto`                                                                   |
| **Frontend Port** | 3000                                                                       |
| **API Port**      | 8000                                                                       |
| **Database**      | PostgreSQL (in cluster)                                                    |
| **Cache**         | Redis (in cluster)                                                         |
| **Credentials**   | Stored in Vault: `secret/swimto/*`                                         |

### Journey (Career Pathfinder)

| Property        | Value                                           |
| --------------- | ----------------------------------------------- |
| **Local URL**   | `https://journey.eldertree.local` (if deployed) |
| **Namespace**   | `journey`                                       |
| **Database**    | PostgreSQL (in cluster)                         |
| **Credentials** | Stored in Vault: `secret/journey/*`             |

### NIMA (AI/ML Learning)

| Property        | Value                                        |
| --------------- | -------------------------------------------- |
| **Local URL**   | `https://nima.eldertree.local` (if deployed) |
| **Namespace**   | `nima`                                       |
| **Credentials** | Stored in Vault: `secret/nima/*`             |

---

## 🌐 Public Services (Pitanga LLC)

### Pitanga Website

| Property        | Value                                                  |
| --------------- | ------------------------------------------------------ |
| **Public URLs** | `https://pitanga.cloud`<br>`https://www.pitanga.cloud` |
| **Local URL**   | `https://pitanga.eldertree.local`                      |
| **Namespace**   | `pitanga`                                              |
| **TLS**         | Cloudflare Origin Certificate                          |
| **Access**      | Public (via Cloudflare Tunnel)                         |

### Northwaysignal Website

| Property       | Value                                  |
| -------------- | -------------------------------------- |
| **Public URL** | `https://northwaysignal.pitanga.cloud` |
| **Namespace**  | `pitanga`                              |
| **TLS**        | Cloudflare Origin Certificate          |
| **Access**     | Public (via Cloudflare Tunnel)         |

---

## 🔐 Getting Credentials

### Method 1: Vault UI (Recommended)

1. **Port forward to Vault:**

   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   kubectl port-forward -n vault svc/vault 8200:8200
   ```

2. **Open browser:** `https://localhost:8200` (accept self-signed cert)

3. **Login with root token** (stored in password manager)

4. **Navigate to secrets:**
   - Grafana: `secret/monitoring/grafana`
   - Pi-hole: `secret/pi-fleet/pihole/webpassword`
   - Application secrets: `secret/<app-name>/*`

### Method 2: kubectl exec (Command Line)

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Get Vault pod name
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Login to Vault
kubectl exec -n vault $VAULT_POD -- vault login
# Enter root token when prompted

# Read a secret (example: Grafana)
kubectl exec -n vault $VAULT_POD -- vault kv get secret/monitoring/grafana

# Read Pi-hole password
kubectl exec -n vault $VAULT_POD -- vault kv get secret/pi-fleet/pihole/webpassword
```

### Method 3: External Secrets (Kubernetes Secrets)

External Secrets Operator syncs secrets from Vault to Kubernetes automatically:

```bash
export KUBECONFIG=~/.kube/config-eldertree

# List all ExternalSecrets
kubectl get externalsecrets -A

# Get Grafana credentials (synced to Kubernetes)
kubectl get secret grafana-admin -n observability -o jsonpath='{.data.adminUser}' | base64 -d
kubectl get secret grafana-admin -n observability -o jsonpath='{.data.adminPassword}' | base64 -d

# Get Pi-hole password
kubectl get secret pihole-secrets -n pihole -o jsonpath='{.data.webpassword}' | base64 -d
```

### Method 4: Backup File (If Available)

If you have a Vault backup file:

```bash
# View backup (contains all secrets in plain text)
cat vault-backup-YYYYMMDD.json | jq '.secrets'
```

**⚠️ Security Warning:** Backup files contain plaintext secrets. Store securely!

---

## 🔑 Common Credential Paths in Vault

### Infrastructure

- `secret/pi-fleet/pihole/webpassword` - Pi-hole admin password
- `secret/pi-fleet/terraform/cloudflare-api-token` - Cloudflare API token
- `secret/pi-fleet/cloudflare-tunnel/token` - Cloudflare Tunnel token
- `secret/pi-fleet/flux/git` - Flux Git SSH private key
- `secret/pi-fleet/tailscale` - Tailscale auth key for subnet routers

### Monitoring

- `secret/monitoring/grafana` - Grafana admin (`adminUser`, `adminPassword`)

### Applications

- `secret/canopy/postgres` - Canopy PostgreSQL password
- `secret/canopy/app` - Canopy application secret key
- `secret/swimto/database` - SwimTO database URL
- `secret/swimto/postgres` - SwimTO PostgreSQL password
- `secret/swimto/redis` - SwimTO Redis URL
- `secret/swimto/app` - SwimTO admin token and secret key
- `secret/swimto/api-keys` - OpenAI and Leonardo.ai API keys
- `secret/swimto/oauth` - Google OAuth client ID and secret
- `secret/journey/postgres` - Journey PostgreSQL password
- `secret/journey/database` - Journey database URL

### Pitanga

- `secret/pitanga/ghcr-token` - GitHub Container Registry token
- `secret/pitanga/cloudflare-origin-cert` - Cloudflare Origin Certificate

---

## 🌍 Remote Access

### Tailscale VPN (Recommended for Full Access)

Tailscale provides secure VPN access from anywhere with automatic HA failover.

| Node   | Tailscale IP     | Advertised Subnets                                     |
|--------|------------------|--------------------------------------------------------|
| node-1 | 100.86.241.124   | 192.168.2.0/24, 10.42.0.0/16, 10.43.0.0/16            |
| node-2 | 100.116.185.57   | 192.168.2.0/24, 10.42.0.0/16, 10.43.0.0/16            |
| node-3 | 100.104.30.105   | 192.168.2.0/24, 10.42.0.0/16, 10.43.0.0/16            |

**Features:**
- ✅ Full network access (LAN, pods, services)
- ✅ kubectl access from anywhere
- ✅ SSH to nodes from anywhere
- ✅ Automatic failover (~15 seconds)
- ✅ No port forwarding required

**Client Setup:**
1. Install Tailscale: https://tailscale.com/download
2. Login with same account used for cluster
3. Enable **"Accept Routes"** in Tailscale preferences
4. Access services via LAN IPs (192.168.2.x) or Tailscale IPs (100.x.x.x)

**kubeconfig for Remote Access:**

| Location | kubeconfig | API Server |
|----------|-----------|------------|
| Home (LAN) | `~/.kube/config-eldertree` | 192.168.2.100:6443 |
| Remote | `~/.kube/config-eldertree-remote` | 100.86.241.124:6443 |

```bash
# When remote (mobile, travel, etc.)
export KUBECONFIG=~/.kube/config-eldertree-remote
kubectl get nodes
```

**Auth Key:** Stored in Vault at `secret/pi-fleet/tailscale`

**Ansible Playbook:** `ansible/playbooks/install-tailscale.yml`

**Full Documentation:** See `docs/TAILSCALE.md`

### Cloudflare Tunnel (Public Services)

Public services are accessible via Cloudflare Tunnel:

- **SwimTO:** `https://swimto.eldertree.xyz`
- **Pitanga:** `https://pitanga.cloud` and `https://www.pitanga.cloud`
- **Northwaysignal:** `https://northwaysignal.pitanga.cloud`

**Configuration:** Managed via Terraform (`terraform/cloudflare.tf`)

**Tunnel Token:** Stored in Vault at `secret/pi-fleet/cloudflare-tunnel/token`

---

## 🛠️ Quick Commands

### Check Service Status

```bash
export KUBECONFIG=~/.kube/config-eldertree

# All pods
kubectl get pods -A

# Specific namespace
kubectl get pods -n <namespace>

# Services
kubectl get svc -A

# Ingresses
kubectl get ingress -A
```

### Port Forward to Services

```bash
# Vault
kubectl port-forward -n vault svc/vault 8200:8200

# Grafana
kubectl port-forward -n observability svc/grafana 3000:80

# Prometheus
kubectl port-forward -n observability svc/prometheus-server 9090:80
```

### Test DNS Resolution

```bash
# Test local DNS
nslookup vault.eldertree.local 192.168.2.201
nslookup grafana.eldertree.local 192.168.2.201

# Test from any device (if router DNS is configured)
nslookup vault.eldertree.local
```

### Unseal Vault (After Restart)

```bash
export KUBECONFIG=~/.kube/config-eldertree
./scripts/operations/unseal-vault.sh
```

---

## 📝 Notes

- **TLS Certificates:** Local services use self-signed certificates. Accept browser warnings for `*.eldertree.local` domains.
- **Public Services:** Use Cloudflare Origin Certificates (valid TLS).
- **DNS:** Ensure router DNS is set to `192.168.2.201` for automatic `*.eldertree.local` resolution.
- **Vault:** Always unseal after cluster restart using the unseal script.
- **Credentials:** Never commit credentials to Git. All secrets are in Vault.

---

## 🔗 Related Documentation

- **Vault Management:** `VAULT.md`, `docs/VAULT_QUICK_REFERENCE.md`
- **Network Setup:** `NETWORK.md`
- **Deployment Guide:** `clusters/eldertree/README.md`
- **Troubleshooting:** `docs/` directory

---

**For detailed setup instructions, see the main README.md and documentation in the `docs/` directory.**
