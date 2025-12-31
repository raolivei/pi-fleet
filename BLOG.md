# Building Eldertree: A Journey in Self-Hosted Kubernetes

> A comprehensive diary of building a production-ready Kubernetes cluster on Raspberry Pi hardware, documenting hardware decisions, software choices, challenges, and lessons learned.

## Table of Contents

- [Introduction](#introduction)
- [Chapter 1: The Vision](#chapter-1-the-vision)
- [Chapter 2: Hardware Decisions](#chapter-2-hardware-decisions)
- [Chapter 3: Operating System and Base Setup](#chapter-3-operating-system-and-base-setup)
- [Chapter 4: Kubernetes Choice - Why K3s](#chapter-4-kubernetes-choice---why-k3s)
- [Chapter 5: Initial Cluster Setup](#chapter-5-initial-cluster-setup)
- [Chapter 6: Networking Architecture](#chapter-6-networking-architecture)
- [Chapter 7: Secrets Management with Vault](#chapter-7-secrets-management-with-vault)
- [Chapter 8: DNS and Service Discovery](#chapter-8-dns-and-service-discovery)
- [Chapter 9: Monitoring and Observability](#chapter-9-monitoring-and-observability)
- [Chapter 10: GitOps with FluxCD](#chapter-10-gitops-with-fluxcd)
- [Chapter 11: Deploying Applications](#chapter-11-deploying-applications)
- [Chapter 12: Storage and Persistence](#chapter-12-storage-and-persistence)
- [Chapter 13: Remote Access and Security](#chapter-13-remote-access-and-security)
- [Chapter 14: Troubleshooting and Lessons Learned](#chapter-14-troubleshooting-and-lessons-learned)
- [Chapter 15: Future Plans and Scaling](#chapter-15-future-plans-and-scaling)
- [Appendix: Reference Materials](#appendix-reference-materials)

---

## Introduction

**Eldertree** is my self-hosted Kubernetes cluster running on Raspberry Pi hardware. This blog documents the complete journey from initial concept to a production-ready infrastructure that hosts multiple applications, manages secrets securely, and provides monitoring and observability.

**Why this blog?** Building a Kubernetes cluster on ARM hardware comes with unique challenges and decisions. This documentation serves as both a personal record and a resource for others embarking on similar journeys. Through 212 commits, 45 pull requests, and solving 92 problems, this journey represents months of learning, troubleshooting, and iteration.

**Cluster Name:** The name "eldertree" reflects the wisdom and stability I hoped to build into this infrastructure - a foundational system that grows and supports other projects. Like an elder tree that has weathered storms and provided shelter for generations, this cluster is designed to be resilient, learn from challenges, and support future growth.

**Current Status:**

- **Control Plane:** eldertree (192.168.2.83)
- **Hardware:** Raspberry Pi 5 (8GB, ARM64)
- **OS:** Debian 12 Bookworm
- **Kubernetes:** K3s v1.33.5+k3s1
- **Status:** ✅ Production-ready, hosting multiple services

**The Journey in Numbers:**

- **212 commits** documenting every decision, problem, and solution
- **45 pull requests** with detailed discussions and reviews
- **92 problems solved** - each one a learning opportunity
- **91 features added** - building capabilities incrementally
- **68 bug fixes** (32% of commits) - resilience through iteration
- **31 new features** (14.6% of commits) - continuous improvement
- **22 documentation updates** (10.3% of commits) - knowledge preservation

**What You'll Learn:**

- How to build a production-ready Kubernetes cluster on Raspberry Pi
- ARM64 compatibility challenges and solutions
- Secrets management with Vault in production
- DNS architecture for local services
- Monitoring and observability on resource-constrained hardware
- GitOps workflows with FluxCD
- Troubleshooting strategies that actually work
- Lessons learned from real-world problems

---

## Chapter 1: The Vision

The eldertree cluster didn't start as a grand plan—it began with a simple need: run my personal applications without depending on cloud providers. What started as a single Raspberry Pi running Docker containers evolved into a full Kubernetes cluster, teaching me more about infrastructure, resilience, and problem-solving than I ever expected.

### Why Self-Host?

The decision to self-host came from several motivations:

**Privacy and Data Ownership**

- My personal finance data (Canopy) shouldn't live on someone else's servers
- User data for commercial projects (SwimTO) requires full control
- Learning projects (NIMA, Journey) generate data I want to own completely

**Learning Kubernetes Hands-On**

- Reading about Kubernetes isn't the same as running it
- Production experience teaches lessons you can't learn from tutorials
- Understanding the full stack from hardware to applications

**Cost-Effective Infrastructure**

- Raspberry Pi 5 costs less than a month of cloud hosting
- No ongoing monthly fees
- Power consumption is minimal (~5-10W)

**Full Control Over the Stack**

- Choose my own tools and versions
- No vendor lock-in
- Customize everything to my needs
- Learn how everything actually works

### Goals

When I started, I had a clear set of goals:

✅ **Run Personal Applications**

- **Canopy** - Personal finance dashboard (private financial data)
- **SwimTO** - Toronto pool schedules (commercial project)
- **Journey** - AI-powered career pathfinder (learning project)
- **NIMA** - AI/ML learning project (experimentation)
- **US Law Severity Map** - Data visualization project

✅ **Learn Kubernetes in Production**

- Not just tutorials—real production workloads
- Understand the full lifecycle: deployment, scaling, troubleshooting
- Learn from real problems, not contrived examples

✅ **Build a Resilient, Maintainable Infrastructure**

- Infrastructure as Code (GitOps with FluxCD)
- Automated deployments
- Proper monitoring and alerting
- Documentation for future reference

✅ **Implement Proper Secrets Management**

- No secrets in Git
- Policy-based access control
- Integration with Kubernetes (External Secrets Operator)
- Production-grade security

✅ **Set Up Monitoring and Observability**

- Know what's happening in the cluster
- Catch problems before they become critical
- Understand resource usage
- Raspberry Pi-specific metrics

✅ **Enable GitOps Workflows**

- All infrastructure in Git
- Automated synchronization
- Easy rollbacks
- Version-controlled configuration

### Constraints

Every project has constraints, and eldertree was no exception:

**ARM64 Hardware (Raspberry Pi)**

- Not all container images support ARM64
- Some tools don't have ARM64 builds
- Performance characteristics differ from x86_64
- Learning opportunity, but also a constraint

**Limited Resources (8GB RAM)**

- Can't run everything at once
- Need to optimize resource usage
- Careful resource limit configuration
- Prioritize what's actually needed

**Home Network Environment**

- No static public IP (initially)
- Need secure remote access solution
- DNS resolution for local services
- Network-wide DNS with Pi-hole

**Budget Considerations**

- Single Raspberry Pi 5 (not a multi-node cluster initially)
- No expensive hardware
- Use what's available
- Cost-effective solutions

### The Evolution

What started as "let's run a few Docker containers" quickly became "let's build a proper Kubernetes cluster." The journey wasn't linear:

1. **Initial Phase (October 2025):** Started with US Law Severity Map project
2. **Infrastructure Phase (November 2025):** Set up K3s cluster, Terraform, FluxCD
3. **Services Phase (November-December 2025):** Added Vault, monitoring, DNS, applications
4. **Optimization Phase (December 2025):** Fixed issues, optimized resources, improved documentation

Each phase taught new lessons and revealed new requirements. The cluster evolved organically, solving problems as they arose, rather than following a rigid plan.

### What I Learned About Planning

Looking back, I realize that:

- **Starting simple was the right choice** - Single node, basic setup, then grow
- **Problems are learning opportunities** - Each of the 92 problems taught something valuable
- **Documentation is critical** - Without it, you repeat the same mistakes
- **Git history tells the story** - Commits document the journey better than memory
- **Iteration beats perfection** - Ship, learn, improve, repeat

### The Name: Eldertree

Why "eldertree"? The name came from wanting something that represented:

- **Wisdom** - Learning from experience and mistakes
- **Stability** - A foundation that supports other projects
- **Growth** - Starting small but designed to expand
- **Resilience** - Weathering challenges and continuing to thrive

Like an elder tree in a forest, this cluster is meant to be a foundational piece of infrastructure that supports other projects, learns from challenges, and grows stronger over time.

---

## Chapter 2: Hardware Decisions

### Why Raspberry Pi 5?

**Decision:** Raspberry Pi 5 (8GB RAM, ARM64)

**Rationale:**

- [ ] Cost-effective compared to cloud hosting
- [ ] Low power consumption
- [ ] ARM64 architecture (learning opportunity)
- [ ] 8GB RAM sufficient for small cluster
- [ ] Active community and support

**Specifications:**

- **Model:** Raspberry Pi 5
- **RAM:** 8GB
- **Architecture:** ARM64
- **Storage:** [SD Card / NVMe - document your choice]
- **Network:** Gigabit Ethernet
- **Power:** [Power supply details]

### Storage Decisions

**Initial Setup:** [SD Card / NVMe]

- **Why:** [Document your reasoning]
- **Performance considerations:** [I/O performance, reliability]
- **Migration path:** [If you migrated from SD to NVMe, document the process]

### Network Setup

- **IP Assignment:** Static IP via DHCP reservation (192.168.2.83)
- **Network:** 192.168.2.0/24
- **DNS:** Pi-hole as network-wide DNS server

### Cooling and Power

- [ ] Cooling solution (if any)
- [ ] Power supply considerations
- [ ] Thermal management

### Lessons Learned

- [ ] What worked well
- [ ] What you'd change
- [ ] Performance bottlenecks discovered

---

## Chapter 3: Operating System and Base Setup

### OS Choice: Debian 12 Bookworm

**Decision:** Debian 12 Bookworm

**Rationale:**

- [ ] Stability and reliability
- [ ] Excellent ARM64 support
- [ ] Long-term support
- [ ] Package availability
- [ ] Compatibility with K3s

### Initial Setup Process

1. **OS Installation**

   - [ ] Method used (Raspberry Pi Imager, manual, etc.)
   - [ ] Initial configuration steps
   - [ ] User setup and SSH configuration

2. **System Configuration**

   - [ ] Hostname: `eldertree`
   - [ ] Static IP configuration
   - [ ] SSH key setup
   - [ ] Firewall rules
   - [ ] System updates

3. **Prerequisites Installation**
   - [ ] Required packages
   - [ ] System dependencies
   - [ ] Network configuration

### Automation with Ansible

**Tool Choice:** Ansible for system configuration

**Benefits:**

- Idempotent configuration
- Version-controlled setup
- Reproducible deployments
- Clear separation of concerns

**Key Playbooks:**

- `setup-system.yml` - Base system configuration
- `install-k3s.yml` - K3s installation
- `bootstrap-flux.yml` - GitOps bootstrap

### Lessons Learned

- [ ] Importance of automation from the start
- [ ] Configuration management benefits
- [ ] Challenges with ARM64 packages

---

## Chapter 4: Kubernetes Choice - Why K3s

### Why K3s Over Full Kubernetes?

**Decision:** K3s (lightweight Kubernetes distribution)

**Rationale:**

- [ ] **Resource Efficiency:** Designed for edge/IoT, minimal overhead
- [ ] **ARM64 Support:** Excellent support for Raspberry Pi
- [ ] **Simplified Setup:** Single binary, no complex dependencies
- [ ] **Built-in Components:** Traefik ingress, local-path storage included
- [ ] **Production Ready:** CNCF certified, used in production environments
- [ ] **Single Node Friendly:** Works well for small clusters

### K3s Architecture

- **Control Plane:** Embedded etcd (no external etcd needed)
- **Ingress:** Traefik (pre-installed)
- **Storage:** local-path-provisioner (pre-installed)
- **Service Load Balancer:** Klipper (pre-installed)

### Version

- **K3s Version:** v1.33.5+k3s1
- **Kubernetes API:** Compatible with standard Kubernetes APIs
- **Helm Version:** v4.0.0

### Trade-offs

**Pros:**

- ✅ Low resource usage
- ✅ Easy installation
- ✅ Built-in components reduce complexity
- ✅ Active development and support

**Cons:**

- ⚠️ Some advanced features may differ from full Kubernetes
- ⚠️ Community smaller than full Kubernetes
- ⚠️ Some third-party tools may need adaptation

### Lessons Learned

- [ ] K3s was the right choice for this use case
- [ ] Built-in Traefik simplified ingress setup
- [ ] local-path-provisioner sufficient for single-node

---

## Chapter 5: Initial Cluster Setup

The initial cluster setup happened in November 2025, starting with infrastructure as code and ending with a working Kubernetes cluster hosting multiple services. This chapter documents that journey, based on the actual Git commit history.

### The Timeline: November 2025

**November 6, 2025 - The Beginning**

The journey started with infrastructure as code. The first commit set up Terraform for the eldertree control plane:

```bash
feat: Add k3s cluster setup with Terraform for eldertree control plane
```

This established the pattern that would define the entire project: **everything in Git, everything automated**.

**November 7, 2025 - Foundation Day**

This was a busy day with multiple foundational pieces:

1. **Git Workflow Established**

   - Added git branching strategy and contributing guidelines
   - Set up the workflow that would support 45 pull requests

2. **K9s Installation**

   - Added k9s (Kubernetes CLI) to the control plane
   - Essential tool for cluster management and troubleshooting

3. **Network Documentation**

   - Created NETWORK.md with IP configuration and service domains
   - Documented the `.eldertree.local` domain strategy
   - Set up FluxCD GitOps foundation

4. **Cluster Naming**
   - Standardized cluster name to 'eldertree' across all kubeconfig contexts
   - Important for consistency across tools and scripts

### Installation Process

**Method:** Automated via Ansible playbook

The actual K3s installation was handled by Ansible, ensuring:

- Idempotent configuration (can run multiple times safely)
- Version-controlled setup
- Reproducible deployments
- Clear separation of concerns

**Steps:**

1. **System Preparation**

   - Base system configuration via Ansible
   - User setup, hostname, network configuration
   - Required packages installation

2. **K3s Binary Installation**

   - Automated via `ansible/playbooks/install-k3s.yml`
   - Single binary installation (no complex dependencies)
   - ARM64 compatible out of the box

3. **Cluster Initialization**

   - Embedded etcd (no external etcd needed)
   - Traefik ingress controller (pre-installed)
   - local-path storage provisioner (pre-installed)
   - CoreDNS for service discovery (pre-installed)

4. **Kubeconfig Setup**

   - Ansible playbook configured kubeconfig
   - Cluster and context renamed to "eldertree"
   - Stored at `~/.kube/config-eldertree`

5. **Verification**
   ```bash
   export KUBECONFIG=~/.kube/config-eldertree
   kubectl get nodes
   kubectl get pods -A
   kubectl cluster-info
   ```

### Cluster Configuration

The initial cluster configuration:

```yaml
Cluster Name: eldertree
Control Plane: eldertree (192.168.2.83)
Kubernetes Version: v1.33.5+k3s1
Storage Class: local-path (built-in)
Ingress Class: traefik (built-in)
Service Load Balancer: Klipper (built-in)
```

**Key Decisions:**

- Single-node cluster initially (sufficient for learning and small workloads)
- Embedded etcd (simpler than external etcd for single node)
- Built-in components (Traefik, local-path) reduce complexity
- Standard Kubernetes APIs (compatible with all K8s tools)

### First Pods

After installation, the cluster automatically started these system pods:

**kube-system namespace:**

- `traefik` - Ingress controller (pre-installed with K3s)
- `local-path-provisioner` - Storage provisioner
- `coredns` - DNS server for service discovery
- `svclb-traefik` - Service load balancer for Traefik
- `metrics-server` - Resource metrics API

**Key Insight:** K3s includes many components that would require separate installation in full Kubernetes. This simplicity was a major advantage.

### Early Additions (November 7, 2025)

**Cert-Manager and Monitoring Stack**

The same day as cluster setup, cert-manager and monitoring were added:

```bash
feat: add cert-manager and monitoring stack
- Deploy cert-manager with self-signed ClusterIssuer
```

This established the pattern of **adding infrastructure incrementally** rather than all at once.

**Initial Challenges:**

- Had to add `open-iscsi` for Longhorn (later removed)
- Fixed cert-manager dependencies
- Configured storage classes for Prometheus and Grafana

### Verification and Testing

**Basic Cluster Health:**

```bash
# Check nodes
kubectl get nodes
# NAME        STATUS   ROLES                  AGE   VERSION
# eldertree   Ready    control-plane,master   1d    v1.33.5+k3s1

# Check system pods
kubectl get pods -A
# All system pods should be Running

# Check cluster info
kubectl cluster-info
```

**First Application Test:**

- Deployed a simple nginx pod to verify everything worked
- Created a service and ingress to test Traefik
- Verified DNS resolution with CoreDNS

### Challenges Encountered

**1. Resource Limits on Raspberry Pi**

- **Problem:** Some default resource limits were too high for 8GB RAM
- **Solution:** Adjusted limits for K3s components and applications
- **Lesson:** Always set appropriate resource limits from the start

**2. Storage Configuration**

- **Problem:** PVCs not binding, data not persisting
- **Solution:** Explicitly specified `storageClassName: local-path`
- **Lesson:** Don't rely on default storage classes

**3. Network Setup**

- **Problem:** Services not accessible, DNS not resolving
- **Solution:** Configured static IP, set up Pi-hole for DNS
- **Lesson:** Network configuration is critical for service discovery

**4. Initial Troubleshooting**

- **Problem:** Learning curve for Kubernetes debugging
- **Solution:** Used k9s, kubectl, and documentation
- **Lesson:** Good tools (k9s) make troubleshooting much easier

### The First Week

By the end of the first week (November 13, 2025), the cluster had:

- ✅ Working K3s cluster
- ✅ Cert-manager with self-signed certificates
- ✅ Monitoring stack (Prometheus + Grafana)
- ✅ Network documentation
- ✅ GitOps foundation (FluxCD)
- ✅ Basic troubleshooting experience

**Key Milestones:**

- November 6: Infrastructure as code setup
- November 7: Cluster installation and initial services
- November 13: First major troubleshooting session (multiple fixes)

### Lessons Learned

**What Worked Well:**

- ✅ **Ansible automation** - Made setup reproducible and documented
- ✅ **K3s simplicity** - Built-in components saved time
- ✅ **Incremental approach** - Adding services one at a time was manageable
- ✅ **GitOps from the start** - All configuration in Git from day one

**What Would I Do Differently:**

- 🔄 **Set resource limits earlier** - Would have avoided some debugging
- 🔄 **Document as you go** - Some early decisions weren't documented
- 🔄 **Test storage earlier** - Storage issues appeared later
- 🔄 **Set up monitoring immediately** - Would have caught issues faster

**Key Takeaways:**

- 📝 **Automation is essential** - Ansible playbooks made everything reproducible
- 📝 **Start simple** - Single node, basic setup, then grow
- 📝 **Document decisions** - Git commits document the journey
- 📝 **Incremental is better** - Add one service at a time, learn, then add more
- 📝 **Built-in components help** - K3s includes what you need, reducing complexity

### The Foundation Was Set

By the end of November 2025, eldertree was a working Kubernetes cluster. It wasn't perfect—there were 92 problems to solve over the coming months—but it was functional, documented, and ready to grow. The foundation of infrastructure as code, GitOps, and automation would support all future development.

The journey from "let's set up Kubernetes" to "production-ready cluster" had begun.

---

## Chapter 6: Networking Architecture

### Network Design

**Subnet:** 192.168.2.0/24
**Control Plane IP:** 192.168.2.83 (eldertree)
**DNS Server:** 192.168.2.201 (Pi-hole via MetalLB)

### DNS Strategy

**Approach:** Pi-hole as network-wide DNS server

**Benefits:**

- Ad-blocking for entire network
- Local service resolution (\*.eldertree.local)
- Centralized DNS management
- Performance improvement

### Service Discovery

**Local Domains:** `*.eldertree.local`

- `grafana.eldertree.local`
- `prometheus.eldertree.local`
- `vault.eldertree.local`
- `pihole.eldertree.local`
- `canopy.eldertree.local`
- `swimto.eldertree.local`

### Ingress Configuration

**Ingress Controller:** Traefik (built into K3s)
**TLS:** Cert-Manager with self-signed certificates
**Ingress Class:** `traefik`

### MetalLB for LoadBalancer Services

**Purpose:** Provide LoadBalancer services on bare metal
**Configuration:** Layer 2 mode
**IP Range:** [Document your IP range]

### External DNS

**Tool:** ExternalDNS
**Providers:**

- Cloudflare (for public domains)
- RFC2136 (for local DNS via Pi-hole BIND)

### Lessons Learned

- [ ] DNS is critical for service discovery
- [ ] Pi-hole integration simplified local DNS
- [ ] MetalLB essential for LoadBalancer services
- [ ] ExternalDNS automation saves time

---

## Chapter 7: Secrets Management with Vault

### Why Vault?

**Decision:** HashiCorp Vault for secrets management

**Rationale:**

- [ ] Industry-standard secrets management
- [ ] Policy-based access control
- [ ] Integration with Kubernetes
- [ ] Audit capabilities
- [ ] Support for multiple secret engines

### Deployment Journey

**Initial Setup:** Dev mode (no persistence)
**Migration:** Production mode with persistent storage

**Key Dates:**

- November 17, 2025: Initial deployment
- November 23, 2025: Migration to production mode with policies

### Production Configuration

- **Version:** v1.17.2
- **Mode:** Production (with persistence)
- **Storage:** 10Gi persistent volume (local-path)
- **Storage Type:** file backend
- **HA:** Standalone mode (single node)

### Policy-Based Access Control

**Approach:** Per-project policies for isolation

**Policies Created:**

- `canopy-policy` - Access to `secret/canopy/*`
- `swimto-policy` - Access to `secret/swimto/*`
- `journey-policy` - Access to `secret/journey/*`
- `nima-policy` - Access to `secret/nima/*`
- `us-law-severity-map-policy` - Access to `secret/us-law-severity-map/*`
- `monitoring-policy` - Access to `secret/monitoring/*`
- `infrastructure-policy` - Access to `secret/pi-fleet/*`
- `eso-readonly-policy` - Read-only for External Secrets Operator

**Benefits:**

- Least-privilege access
- Project isolation
- Prevents accidental cross-project access
- Better auditability

### External Secrets Operator

**Purpose:** Automatically sync secrets from Vault to Kubernetes
**Configuration:** ClusterSecretStore pointing to Vault
**Sync Frequency:** Every 24 hours (or on-demand)

### Unsealing Process

**Challenge:** Vault seals after each restart
**Solution:** Manual unsealing with 3 of 5 keys
**Automation:** `unseal-vault.sh` script

### Backup Strategy

- Regular backups of all secrets
- Secure storage of unseal keys
- Backup script: `backup-vault-secrets.sh`

### Lessons Learned

- [ ] Production mode requires manual unsealing
- [ ] Policy-based access is essential for multi-project setup
- [ ] External Secrets Operator simplifies secret management
- [ ] Regular backups are critical
- [ ] Unseal keys must be stored securely

### Migration Notes

See: `docs/VAULT_MIGRATION.md` for complete migration guide

---

## Chapter 8: DNS and Service Discovery

### Pi-hole Integration

**Purpose:** Network-wide DNS with ad-blocking
**Deployment:** Kubernetes pod with LoadBalancer service
**IP:** 192.168.2.201 (via MetalLB)

### Local DNS Resolution

**Domain Pattern:** `*.eldertree.local`
**Resolver:** Pi-hole with custom DNS records
**Configuration:** Custom DNS entries for all services

### External DNS Automation

**Tool:** ExternalDNS
**Providers:**

- **Cloudflare:** For public domain management
- **RFC2136:** For local DNS updates via Pi-hole BIND

**Benefits:**

- Automatic DNS record creation
- Ingress-based service discovery
- Reduced manual DNS management

### BIND Integration

**Purpose:** RFC2136 support for ExternalDNS
**Configuration:** BIND sidecar in Pi-hole pod
**TSIG Secret:** Managed via Vault and External Secrets

### Router DNS Configuration

**Setup:** Router DNS set to Pi-hole IP (192.168.2.201)
**Fallback:** 8.8.8.8 (Google DNS) or 1.1.1.1 (Cloudflare DNS)

### Troubleshooting DNS

**Common Issues:**

- DNS not resolving after deployment
- Pi-hole pod not ready
- BIND service unavailable
- TSIG secret missing

**Solutions:**

- Check Pi-hole pod status
- Verify BIND sidecar logs
- Ensure TSIG secret exists in Vault
- Check ExternalDNS logs

### A Real-World DNS Troubleshooting Story

One morning, I woke up to find that none of my services were reachable. Simple commands like `ping vault.eldertree.local` returned "Unknown host" errors. This was particularly frustrating because everything had been working fine the day before. When DNS breaks in a self-hosted cluster, nothing works—services become unreachable, monitoring fails, and the entire infrastructure feels broken.

This is the story of that morning and what I learned about debugging DNS in Kubernetes.

#### The Architecture (Context)

Before diving into the troubleshooting, it's important to understand the setup:

- **Kubernetes**: k3s v1.33.6 running on Raspberry Pi 5
- **DNS Server**: Pi-hole running in Kubernetes with BIND for custom zone resolution
- **Load Balancing**: MetalLB providing a virtual IP (192.168.2.201) for the Pi-hole service
- **Custom Domains**: `.eldertree.local` domains resolving to cluster services
- **Network**: Local network (192.168.2.0/24) with router DNS pointing to Pi-hole

The Pi-hole deployment is a multi-container pod:

- **pihole container**: Main DNS server (port 53)
- **bind container**: BIND DNS server (port 5353) for custom zone resolution
- **bind-init container**: Init container that sets up BIND configuration

This multi-container setup is crucial to understanding what went wrong.

#### The Investigation

**Step 1: Check Pod Status**

First, I checked if Pi-hole was running:

```bash
kubectl get pods -n pihole
```

**Finding**: One pod was `1/2 Ready` (pihole container ready, bind container not ready), and another pod was `Pending`. This was the first clue—the pod wasn't fully ready.

**Step 2: Test DNS Resolution**

I tried to query DNS directly:

```bash
nslookup vault.eldertree.local 192.168.2.201
```

**Result**: Connection timeout. The LoadBalancer IP wasn't responding.

**Step 3: Check Service Endpoints**

I checked if the service had endpoints:

```bash
kubectl get endpoints -n pihole pi-hole
```

**Finding**: The service had no endpoints! This meant Kubernetes wasn't routing traffic to the pod, even though a pod existed.

**Step 4: Inspect Pod Containers**

I checked which containers were ready:

```bash
kubectl get pod -n pihole pi-hole-58d9d66bd5-sxdw8 -o jsonpath='{.status.containerStatuses[*].name}'
kubectl get pod -n pihole pi-hole-58d9d66bd5-sxdw8 -o jsonpath='{.status.containerStatuses[*].ready}'
```

**Result**: `bind pihole` and `true false`—the bind container wasn't ready.

**Step 5: Test DNS from Inside the Pod**

I tested DNS resolution from inside the pod:

```bash
kubectl exec -n pihole pi-hole-58d9d66bd5-sxdw8 -c pihole -- nslookup vault.eldertree.local 127.0.0.1
```

**Result**: `SERVFAIL`—DNS was running but couldn't resolve the custom zone. The BIND container wasn't ready, so the zone configuration wasn't active.

**Step 6: Check Init Container**

I checked the init container logs:

```bash
kubectl logs -n pihole pi-hole-58d9d66bd5-sxdw8 -c bind-init
```

**Result**: Empty—the init container had completed, but something was preventing the bind container from starting properly.

**Step 7: Verify Ports Are Listening**

I checked if DNS was actually listening:

```bash
kubectl exec -n pihole pi-hole-58d9d66bd5-sxdw8 -c pihole -- netstat -tuln | grep 53
```

**Result**: Port 53 was listening! DNS was running, but the readiness probe was failing.

**Step 8: Check Readiness Probe**

I inspected the readiness probe configuration:

```bash
kubectl describe pod -n pihole pi-hole-58d9d66bd5-sxdw8 | grep -A 5 "Readiness:"
```

**Finding**: The readiness probe was a TCP socket check on port 53 with:

- `initialDelaySeconds: 60`
- `periodSeconds: 10`
- `timeoutSeconds: 5`
- `failureThreshold: 3`

The probe was likely failing because while port 53 was listening, the DNS service wasn't fully initialized (BIND zone not configured).

#### The Root Causes

After investigation, I identified three interconnected issues:

**1. Pod Not Fully Ready**

The Pi-hole pod had two containers, but only one was ready:

- ✅ `pihole` container: Ready (port 53 listening)
- ❌ `bind` container: Not ready (BIND zone not configured)

Kubernetes only considers a pod "ready" when **all** containers pass their readiness probes. Since the bind container wasn't ready, the entire pod was marked as not ready.

**2. Service Had No Endpoints**

Because the pod wasn't ready, Kubernetes didn't add it to the service endpoints. This meant:

- The LoadBalancer IP (192.168.2.201) had no backend
- DNS queries to the LoadBalancer IP timed out
- The service was effectively unreachable

**3. DNS Cache Issues**

Even after the pod became ready, my Mac's DNS cache had stale entries. I needed to flush the cache:

```bash
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
```

#### The Solution

The fix was surprisingly simple—I just needed to wait for the pod to become fully ready:

1. **Wait for bind-init to complete**: The init container sets up BIND configuration
2. **Wait for bind container to start**: BIND needs to load the zone configuration
3. **Wait for readiness probe to pass**: Kubernetes needs to verify the pod is healthy
4. **Flush DNS cache**: Clear stale entries on client machines

After a few minutes, the pod became `2/2 Ready`, endpoints were created, and DNS started working again.

#### Testing the Fix

I verified everything was working:

```bash
# Test DNS resolution
nslookup vault.eldertree.local
# Result: 192.168.2.86 ✅

# Test ping
ping -c 2 vault.eldertree.local
# Result: Successful ✅

# Test all services
for service in vault.eldertree.local swimto.eldertree.local canopy.eldertree.local; do
  nslookup $service
done
# Result: All resolving correctly ✅
```

#### Key Takeaways from This Incident

**1. Multi-Container Pods Are Complex**

When a pod has multiple containers, **all** containers must be ready for the pod to be considered ready. This is by design—Kubernetes won't route traffic to a pod until all containers are healthy.

**Lesson**: Check all container statuses, not just the pod status.

**2. Readiness Probes Matter**

Readiness probes determine when a pod is ready to receive traffic. If a probe fails:

- The pod won't be added to service endpoints
- LoadBalancer IPs won't route to the pod
- Services appear "broken" even though containers are running

**Lesson**: Understand your readiness probe configuration and what it's actually checking.

**3. DNS Cache Can Hide Issues**

Client-side DNS caching can make problems appear fixed (or broken) when they're not. Always flush DNS cache when troubleshooting.

**Lesson**: When DNS seems broken, check both server-side (pod status) and client-side (DNS cache).

**4. Init Containers Are Sequential**

Init containers run sequentially and must complete before main containers start. If an init container is slow or fails, the entire pod is delayed.

**Lesson**: Monitor init container logs and ensure they complete successfully.

**5. Service Endpoints Are the Source of Truth**

If a service has no endpoints, traffic won't route—regardless of pod status. Always check endpoints:

```bash
kubectl get endpoints -n <namespace> <service-name>
```

**Lesson**: No endpoints = no traffic, even if pods exist.

#### Troubleshooting Checklist

For future DNS issues, I now use this checklist:

- [ ] Check pod status: `kubectl get pods -n pihole`
- [ ] Verify all containers are ready: `kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].ready}'`
- [ ] Check service endpoints: `kubectl get endpoints -n pihole pi-hole`
- [ ] Test DNS from inside pod: `kubectl exec -n pihole <pod-name> -c pihole -- nslookup <domain> 127.0.0.1`
- [ ] Verify ports are listening: `kubectl exec -n pihole <pod-name> -c pihole -- netstat -tuln | grep 53`
- [ ] Check LoadBalancer IP: `kubectl get svc -n pihole pi-hole`
- [ ] Test DNS from client: `nslookup <domain> <dns-ip>`
- [ ] Flush DNS cache on client: `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder` (macOS)
- [ ] Check init container logs: `kubectl logs -n pihole <pod-name> -c bind-init`
- [ ] Inspect readiness probe: `kubectl describe pod -n pihole <pod-name> | grep -A 5 "Readiness:"`

#### Reflection

Debugging DNS in Kubernetes requires understanding multiple layers:

- Pod lifecycle (init containers, readiness probes)
- Service discovery (endpoints, LoadBalancer)
- DNS server configuration (BIND zones, Pi-hole)
- Client-side caching

The issue wasn't a single point of failure—it was a cascade of interconnected problems. By systematically checking each layer, I was able to identify and resolve the root causes.

For self-hosted Kubernetes clusters, DNS is critical infrastructure. When it breaks, everything breaks. Understanding how to debug it is essential, and this incident taught me that sometimes the solution is simply patience—waiting for all containers to become ready.

### Lessons Learned

- ✅ **Centralized DNS simplifies service discovery** - Pi-hole as network-wide DNS works well
- ✅ **ExternalDNS automation is invaluable** - Automatic DNS record creation saves time
- ✅ **BIND integration required for RFC2136** - Needed for ExternalDNS to work properly
- ✅ **Router-level DNS configuration affects all devices** - One change impacts everything
- ✅ **Multi-container pods require all containers to be ready** - This is critical for service endpoints
- ✅ **Readiness probes determine service availability** - Understanding probes is essential
- ✅ **DNS cache can mask problems** - Always flush cache when troubleshooting
- ✅ **Service endpoints are the source of truth** - No endpoints = no traffic
- ✅ **Systematic troubleshooting works** - Check each layer methodically

---

## Chapter 9: Monitoring and Observability

### Monitoring Stack

**Components:**

- **Prometheus:** Metrics collection and storage
- **Grafana:** Visualization and dashboards
- **kube-state-metrics:** Kubernetes object metrics
- **node-exporter:** Node-level metrics

### Deployment

**Method:** Helm chart (`monitoring-stack`)
**Namespace:** `observability`
**Storage:** 8Gi persistent volume for Prometheus

### Grafana Dashboards

**Dashboards Created:**

- Pi Fleet Overview
- Hardware Health (Raspberry Pi specific)
- Kubernetes Cluster Overview
- [Add other dashboards]

### Metrics Collection

**Sources:**

- Kubernetes API (via kube-state-metrics)
- Node metrics (via node-exporter)
- Application metrics (if exposed)
- Custom metrics (if configured)

### Alerting

**Status:** [Configured / Planned]
**Channels:** [Email / Slack / etc.]

### Access

- **Grafana:** https://grafana.eldertree.local
- **Prometheus:** https://prometheus.eldertree.local

### Lessons Learned

- [ ] Monitoring is essential from day one
- [ ] Raspberry Pi-specific metrics are valuable
- [ ] Persistent storage for Prometheus is critical
- [ ] Grafana dashboards save time in troubleshooting

---

## Chapter 10: GitOps with FluxCD

### Why GitOps?

**Decision:** FluxCD for GitOps workflows

**Rationale:**

- [ ] Infrastructure as Code
- [ ] Version-controlled deployments
- [ ] Automated synchronization
- [ ] Rollback capabilities
- [ ] Multi-environment support

### Bootstrap Process

**Method:** Ansible playbook (`bootstrap-flux.yml`)
**Repository:** [Your Git repository]
**Branch:** `main`
**Path:** `clusters/eldertree/`

### Repository Structure

```
clusters/eldertree/
├── core-infrastructure/
│   ├── cert-manager/
│   └── issuers/
├── secrets-management/
│   ├── vault/
│   └── external-secrets/
├── dns-services/
│   ├── pihole/
│   ├── external-dns/
│   └── wireguard/
└── observability/
    ├── keda/
    └── monitoring-stack/
```

### Helm Releases

**Management:** FluxCD HelmRelease resources
**Charts:** Custom charts in `helm/` directory
**Values:** Managed via Git

### Sync Process

- **Frequency:** Continuous (every 5 minutes)
- **Reconciliation:** Automatic
- **Notifications:** [If configured]

### Benefits Realized

- [ ] All infrastructure changes tracked in Git
- [ ] Easy rollbacks via Git revert
- [ ] Consistent deployments
- [ ] Reduced manual errors

### Lessons Learned

- [ ] GitOps requires discipline in Git workflow
- [ ] Clear directory structure is essential
- [ ] Helm charts simplify application management
- [ ] FluxCD reconciliation is reliable

---

## Chapter 11: Deploying Applications

### Application Portfolio

**Deployed Applications:**

1. **Canopy** - Personal finance dashboard
2. **SwimTO** - Toronto pool schedules
3. **Journey** - AI-powered career pathfinder
4. **NIMA** - AI/ML learning project
5. **US Law Severity Map** - Law visualization
6. **Ollie** - Local AI with memory (planned/in progress)

### Deployment Patterns

**Common Pattern:**

- Helm charts for each application
- External Secrets for credentials
- Ingress resources for external access
- Persistent volumes for data

### Application-Specific Notes

#### Canopy

- **Database:** PostgreSQL
- **Storage:** Persistent volume for database
- **Secrets:** Database password, app secret key
- **Access:** https://canopy.eldertree.local

#### SwimTO

- **Database:** PostgreSQL
- **Cache:** Redis
- **API Keys:** OpenAI, Leonardo.ai
- **OAuth:** Google OAuth
- **Access:** https://swimto.eldertree.local

#### Journey

- **Database:** PostgreSQL
- **Access:** [Document access URL]

#### NIMA

- **Status:** [Document status]
- **Access:** [Document access URL]

### CI/CD Integration

**GitHub Actions:** Automated builds and image publishing
**Container Registry:** GitHub Container Registry (ghcr.io)
**Image Tagging:** Based on branch/tag/PR

### Lessons Learned

- [ ] Consistent deployment patterns simplify management
- [ ] External Secrets integration is seamless
- [ ] Helm charts provide flexibility
- [ ] Resource limits are critical on Raspberry Pi

---

## Chapter 12: Storage and Persistence

### Storage Classes

**Default:** `local-path` (built into K3s)
**Type:** Local filesystem storage
**Limitations:** Single node, no replication

### Persistent Volumes

**Applications Using PVs:**

- Prometheus (8Gi)
- Vault (10Gi)
- [Add other applications]

### Backup Strategy

**Current Approach:** [Document your backup strategy]

- [ ] Vault secrets backup
- [ ] Database backups
- [ ] Configuration backups

### Future Considerations

- [ ] Longhorn for multi-node storage
- [ ] NFS for shared storage
- [ ] External storage solutions

### Lessons Learned

- [ ] local-path sufficient for single-node
- [ ] Persistent volumes essential for stateful apps
- [ ] Backup strategy must be planned early
- [ ] Storage performance can be a bottleneck

---

## Chapter 13: Remote Access and Security

### Remote Access Options

**Options Considered:**

1. **WireGuard VPN** - [Status: Disabled / Enabled]
2. **Cloudflare Tunnel** - [Status: Configured / Planned]

### Cloudflare Tunnel

**Purpose:** Secure remote access without opening ports
**Configuration:** Terraform-managed
**Benefits:**

- No port forwarding required
- HTTPS by default
- Access control via Cloudflare

### WireGuard VPN

**Status:** [Enabled / Disabled]
**Reason:** [Document why enabled or disabled]
**Configuration:** [If enabled, document setup]

### Security Practices

- [ ] TLS/HTTPS for all services
- [ ] Secrets in Vault (not in Git)
- [ ] Policy-based access control
- [ ] Regular updates
- [ ] Network isolation

### Lessons Learned

- [ ] Cloudflare Tunnel simplifies remote access
- [ ] HTTPS is required for OAuth (security requirement)
- [ ] Secrets management is critical
- [ ] Network security requires planning

---

## Chapter 14: Troubleshooting and Lessons Learned

> **Note:** This chapter is based on analysis of 212 Git commits, identifying 92 problems and their solutions. The journey wasn't always smooth, but each challenge taught valuable lessons.

### Major Challenges

#### Challenge 1: Pi-hole Port Conflicts with K3s ServiceLB

**Date:** December 28-30, 2025  
**Commit:** `c3bfadf` (PR #50, #56)

**Problem:**
Pi-hole pod couldn't bind to port 53 (DNS) because K3s ServiceLB was conflicting with the pod's network configuration. The pod would fail to start or DNS resolution would break.

**Symptoms:**

- Pi-hole pod in `CrashLoopBackOff` or `Pending` state
- DNS queries failing
- Port 53 already in use errors
- ServiceLB trying to bind to the same port

**Root Cause:**
K3s includes a built-in ServiceLB (Klipper) that automatically creates LoadBalancer services. When Pi-hole was configured with `hostNetwork: true` or when ServiceLB tried to bind to port 53, conflicts occurred. Additionally, the deployment template didn't explicitly disable `hostNetwork`, leading to unpredictable behavior.

**Investigation:**

1. Checked pod logs: `kubectl logs -n pihole deployment/pi-hole`
2. Verified port binding: `netstat -tuln | grep 53`
3. Examined ServiceLB configuration
4. Reviewed Pi-hole Helm chart deployment template

**Solution:**

1. **Disabled K3s ServiceLB for Pi-hole service:**

   ```yaml
   annotations:
     service.beta.kubernetes.io/k3s-lb: "false"
   ```

2. **Explicitly set `hostNetwork: false` in deployment:**

   ```yaml
   spec:
     hostNetwork: false
   ```

3. **Used MetalLB for LoadBalancer functionality** instead of ServiceLB

4. **Added comprehensive documentation** in Pi-hole README with troubleshooting guide

**Prevention:**

- Always explicitly set `hostNetwork` in deployment templates (don't rely on defaults)
- Document network requirements for services using privileged ports
- Use MetalLB for LoadBalancer services on bare metal instead of ServiceLB when conflicts occur
- Add health checks and readiness probes to detect port conflicts early

**Lessons Learned:**

- K3s ServiceLB can conflict with pods using privileged ports
- Explicit configuration is better than implicit defaults
- MetalLB provides more control for bare-metal Kubernetes
- Documentation helps prevent repeating the same mistakes

---

#### Challenge 2: ARM64 Image Compatibility for BIND

**Date:** November 13, 2025  
**Commit:** `1b41a1c`

**Problem:**
ExternalDNS couldn't connect to BIND service because the BIND container image wasn't ARM64 compatible. The pod would crash or fail to start on Raspberry Pi.

**Symptoms:**

- BIND pod in `ImagePullBackOff` or `CrashLoopBackOff`
- Error: "no matching manifest for linux/arm64"
- ExternalDNS failing to connect to BIND

**Root Cause:**
The default BIND image in the Helm chart was built for AMD64/x86_64 architecture. Raspberry Pi 5 uses ARM64 architecture, so the image couldn't run.

**Solution:**
Switched to an ARM64-compatible BIND image:

```yaml
image:
  repository: internetsystemsconsortium/bind9
  tag: "9.18" # ARM64 compatible version
```

**Prevention:**

- Always verify image architecture compatibility for ARM64 deployments
- Use multi-arch images when available
- Test image pulls before deploying to production
- Document architecture requirements in deployment manifests

**Lessons Learned:**

- ARM64 compatibility is critical for Raspberry Pi deployments
- Not all container images support ARM64
- Always check image architecture before deployment
- Multi-arch images simplify cross-platform deployments

---

#### Challenge 3: Storage Class Configuration for Monitoring Stack

**Date:** November 7, 2025  
**Commits:** `3e8c1ef`, `18872b7`

**Problem:**
Prometheus and Grafana pods couldn't create persistent volumes because the storage class wasn't specified. Pods would start but lose all data on restart.

**Symptoms:**

- Prometheus/Grafana pods starting but data not persisting
- PVCs in `Pending` state
- No storage class assigned to volumes

**Root Cause:**
The monitoring stack Helm chart didn't specify `storageClassName: local-path`, which is the default storage class in K3s. Without explicit configuration, PVCs couldn't bind to volumes.

**Solution:**
Added explicit storage class configuration:

```yaml
persistence:
  enabled: true
  storageClass: "local-path"
  size: 8Gi # Prometheus
  # size: 2Gi  # Grafana
```

**Prevention:**

- Always specify storage class explicitly in Helm values
- Document storage requirements for stateful applications
- Verify PVC status after deployment: `kubectl get pvc -A`
- Use appropriate storage class for single-node vs multi-node clusters

**Lessons Learned:**

- Explicit storage class configuration prevents binding issues
- `local-path` is perfect for single-node K3s clusters
- Stateful applications require persistent storage planning
- Always verify PVC status after deployment

---

#### Challenge 4: BIND DNS Resolution and ExternalDNS Integration

**Date:** November 13, 2025  
**Commits:** `50a6ce8`, `1713866`

**Problem:**
ExternalDNS couldn't update DNS records via BIND because:

1. BIND couldn't resolve upstream DNS queries
2. ExternalDNS was pointing to node IP instead of BIND service

**Symptoms:**

- ExternalDNS pod in `CrashLoopBackOff`
- DNS record updates failing
- BIND logs showing DNS resolution errors

**Root Cause:**

1. BIND was configured to use itself for DNS resolution (circular dependency)
2. ExternalDNS RFC2136 provider was configured with node IP instead of BIND ClusterIP service

**Solution:**

1. **Configured BIND to use CoreDNS for upstream resolution:**

   ```yaml
   environment:
     - name: RESOLVER
       value: "kube-dns.kube-system.svc.cluster.local"
   ```

2. **Updated ExternalDNS to use BIND ClusterIP:**
   ```yaml
   rfc2136:
     host: "bind.pihole.svc.cluster.local" # Instead of node IP
   ```

**Prevention:**

- Always use Kubernetes service DNS names instead of node IPs
- Configure proper DNS resolution chains (avoid circular dependencies)
- Test DNS updates after ExternalDNS configuration
- Monitor ExternalDNS logs for connection errors

**Lessons Learned:**

- Kubernetes service discovery is more reliable than node IPs
- DNS resolution chains must be properly configured
- ExternalDNS requires proper BIND/RFC2136 configuration
- Service DNS names survive node IP changes

---

#### Challenge 5: Vault Sealing After Raspberry Pi Restart

**Date:** November 17-23, 2025  
**Related:** Migration from dev mode to production mode

**Problem:**
After each Raspberry Pi restart, Vault would start in a sealed state, requiring manual unsealing with 3 of 5 keys. This broke all applications depending on secrets from Vault.

**Symptoms:**

- Vault pod running but sealed
- External Secrets Operator failing to sync
- Applications unable to start (missing secrets)
- Error: "Vault is sealed"

**Root Cause:**
Vault in production mode requires manual unsealing after each restart for security. This is expected behavior but wasn't initially documented or automated.

**Solution:**

1. **Created automated unsealing script:**

   ```bash
   ./scripts/operations/unseal-vault.sh
   ```

2. **Documented the unsealing process** in VAULT.md

3. **Added Vault status checks** to deployment validation scripts

4. **Created backup/restore scripts** for unseal keys

**Prevention:**

- Document manual steps required after restarts
- Create automation scripts for repetitive tasks
- Store unseal keys securely (password manager)
- Add Vault status to monitoring dashboards
- Consider auto-unseal with cloud KMS for production (future)

**Lessons Learned:**

- Production Vault requires manual unsealing (security feature)
- Automation scripts save time for repetitive tasks
- Documentation is critical for operational procedures
- Monitoring should include Vault seal status
- Backup unseal keys securely (they can't be recovered)

### Common Issues

Based on analysis of 92 problems identified in the Git history, here are the most common categories:

1. **Vault Sealing After Restart** (Multiple occurrences)

   - **Solution:** Automated unsealing script (`./scripts/operations/unseal-vault.sh`)
   - **Prevention:** Document unsealing process, add to monitoring
   - **Frequency:** Every restart (expected behavior in production mode)

2. **DNS Resolution Issues** (15+ related commits)

   - **Common causes:** Pi-hole not ready, BIND service unavailable, ExternalDNS misconfiguration, multi-container pod readiness
   - **Solution:** Verify Pi-hole and BIND status, check ExternalDNS logs, wait for all containers to be ready
   - **Prevention:** Health checks, proper service DNS configuration, monitoring, understand readiness probes
   - **Key fixes:** ARM64 BIND image, CoreDNS resolution chain, ClusterIP instead of node IP
   - **Detailed case study:** See Chapter 8 for a complete troubleshooting story of a DNS outage caused by multi-container pod readiness issues

3. **Resource Limits on Raspberry Pi** (Multiple occurrences)

   - **Common issue:** "Specified limits are higher than node capacity!"
   - **Solution:** Optimize resource requests/limits for ARM64/Raspberry Pi constraints
   - **Prevention:** Monitor resource usage, set appropriate limits from start
   - **Example fixes:** Reduced FluxCD, KEDA, Journey API limits from 1000m/1Gi to 500m/512Mi

4. **Storage Class Configuration** (Multiple occurrences)

   - **Common issue:** PVCs in Pending state, data not persisting
   - **Solution:** Explicitly specify `storageClassName: local-path` in Helm values
   - **Prevention:** Always configure storage class for stateful applications
   - **Affected services:** Prometheus, Grafana, Vault

5. **Image Pull Issues** (Multiple occurrences)

   - **Common causes:** ARM64 incompatibility, missing GHCR secrets, wrong image tags
   - **Solution:** Verify image architecture, configure imagePullSecrets, use versioned tags
   - **Prevention:** Test image pulls, use ARM64-compatible images, pin image versions
   - **Example fixes:** ARM64 BIND image, versioned SwimTO tags (v0.5.1), GHCR secret configuration

6. **Helm Chart/Template Issues** (Multiple occurrences)
   - **Common issues:** Template syntax errors, missing values, incorrect paths
   - **Solution:** Validate Helm templates, check values.yaml, verify chart paths
   - **Prevention:** Use `helm template` to validate before deployment, test locally
   - **Example fixes:** Dashboard template base functions, correct Helm chart paths in FluxCD

### Debugging Workflow

1. Check pod status: `kubectl get pods -A`
2. Check logs: `kubectl logs <pod> -n <namespace>`
3. Check events: `kubectl get events -A`
4. Check resource usage: Grafana dashboards
5. Check DNS: `nslookup <service>.eldertree.local`

### Lessons Learned Summary

Based on 212 commits, 45 pull requests, and 92 problems solved:

**What Worked Well:**

- ✅ **K3s was the right choice** - Lightweight, ARM64 support, built-in components (Traefik, local-path)
- ✅ **Ansible for automation** - Idempotent configuration, reproducible deployments
- ✅ **GitOps with FluxCD** - All infrastructure as code, easy rollbacks, version control
- ✅ **Vault for secrets management** - Policy-based access, External Secrets integration
- ✅ **Pi-hole for DNS** - Network-wide ad-blocking, local service resolution
- ✅ **Helm charts** - Simplified application deployment and configuration
- ✅ **Git history analysis** - Commits document the journey, problems, and solutions

**What Would I Do Differently:**

- 🔄 **Start with explicit resource limits** - Would have saved time debugging "limits higher than capacity" errors
- 🔄 **Document ARM64 requirements earlier** - Would have avoided image compatibility issues
- 🔄 **Set up monitoring from day one** - Would have caught issues faster
- 🔄 **Use versioned image tags from start** - Would have avoided "latest" tag issues
- 🔄 **Automate Vault unsealing earlier** - Would have reduced manual steps after restarts

**Key Takeaways:**

- 📝 **Automation from the start** - Scripts and Ansible playbooks save time and prevent errors
- 📝 **Documentation is critical** - Every problem solved should be documented to avoid repetition
- 📝 **Monitoring is essential** - Grafana dashboards help identify issues before they become critical
- 📝 **Start simple, add complexity gradually** - Single-node cluster first, then scale
- 📝 **Git history tells the story** - Commit messages document problems, solutions, and decisions
- 📝 **ARM64 requires special attention** - Always verify image compatibility for Raspberry Pi
- 📝 **Explicit configuration beats defaults** - Always specify storage classes, resource limits, network settings
- 📝 **Test before deploying** - Use `helm template`, validate YAML, test locally when possible
- 📝 **PRs provide context** - Pull requests document why changes were made, not just what changed

**Statistics from the Journey:**

- **Total Commits:** 212
- **Pull Requests:** 45
- **Problems Solved:** 92
- **Features Added:** 91
- **Bug Fixes:** 68 (32% of commits)
- **Features:** 31 (14.6% of commits)
- **Documentation:** 22 (10.3% of commits)

**The Journey in Numbers:**
This blog represents months of learning, troubleshooting, and iteration. Each commit tells a story of a problem encountered, investigated, and solved. The 92 problems identified weren't failures—they were learning opportunities that made the cluster more robust and the documentation more comprehensive.

---

## Chapter 15: Future Plans and Scaling

### Short-term Goals

- [ ] Add worker nodes (fleet-worker-01, fleet-worker-02)
- [ ] Implement high availability
- [ ] Add more applications
- [ ] Improve monitoring and alerting
- [ ] Enhance backup strategy

### Long-term Vision

- [ ] Multi-node cluster
- [ ] High availability setup
- [ ] Advanced storage (Longhorn)
- [ ] Enhanced security
- [ ] Disaster recovery plan

### Scaling Considerations

**Horizontal Scaling:**

- Adding worker nodes
- Load distribution
- Resource planning

**Vertical Scaling:**

- Hardware upgrades
- Resource optimization
- Performance tuning

### Technology Roadmap

- [ ] Kubernetes version upgrades
- [ ] New tools and services
- [ ] Architecture improvements
- [ ] Security enhancements

---

## Appendix: Reference Materials

### Key Documentation

- [pi-fleet README](README.md)
- [Network Configuration](NETWORK.md)
- [Vault Guide](VAULT.md)
- [Deployment Summary](DEPLOYMENT_SUMMARY_2025-11-17.md)
- [Vault Deployment Success](VAULT_DEPLOYMENT_SUCCESS.md)

### Useful Commands

```bash
# Cluster access
export KUBECONFIG=~/.kube/config-eldertree

# Check cluster status
kubectl get nodes
kubectl get pods -A

# Vault operations
./scripts/operations/unseal-vault.sh
./scripts/operations/backup-vault-secrets.sh

# FluxCD sync
flux reconcile source git flux-system
flux reconcile kustomization infrastructure
```

### Tools and Versions

- **K3s:** v1.33.5+k3s1
- **Helm:** v4.0.0
- **Vault:** v1.17.2
- **FluxCD:** [Version]
- **Prometheus:** [Version]
- **Grafana:** 11.4.0

### External Resources

- [K3s Documentation](https://k3s.io/)
- [FluxCD Documentation](https://fluxcd.io/)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

---

## How to Use This Blog

### For Authors

1. **Populate Chapters:** Fill in each chapter with your experiences, decisions, and lessons learned
2. **Add Details:** Include specific commands, configurations, and code snippets
3. **Document Challenges:** Record problems encountered and how you solved them
4. **Update Regularly:** Keep the blog current as the cluster evolves

### For Readers

1. **Start with Introduction:** Understand the goals and constraints
2. **Follow Chronologically:** Chapters are organized by journey progression
3. **Reference Appendix:** Use for quick commands and resources
4. **Adapt to Your Needs:** Use as a template for your own journey

### Publishing

When ready to publish:

1. Review and edit for clarity
2. Add diagrams and screenshots
3. Remove sensitive information
4. Export to your preferred format (Markdown, HTML, PDF)
5. Publish to your blog platform

---

**Last Updated:** [Date]
**Cluster Status:** ✅ Production
**Version:** [Current version]

---

_This blog is a living document. As the eldertree cluster evolves, so will this documentation._
