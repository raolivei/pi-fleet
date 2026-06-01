# The Quest for High Availability: A Day in the Life of Eldertree

**Date:** January 10-12, 2026  
**Episode:** "When One Node Goes Down, We All Go Down... Or Do We?"

**Update (January 12):** The saga continues! Longhorn is now fully operational with distributed storage. Scroll to **Act VIII** for the epic conclusion!

---

## 🎙️ Opening Monologue

_[Podcast intro music fades in]_

Welcome back to another episode of "Building Eldertree," where we document the real, unvarnished truth of running a Kubernetes cluster on Raspberry Pis. Today's episode? Well, let's just say it started with a simple question: "What happens if node-1 goes down?"

Spoiler alert: **Everything breaks.**

But that's not where the story ends. Oh no, my friends. That's where it _begins_.

---

## Act I: The Wake-Up Call

Picture this: You've got a beautiful 3-node cluster. Node-1 is your control plane, node-2 and node-3 are workers. Everything's humming along nicely. Vault is storing secrets, Longhorn is managing storage, and your apps are running.

Then you ask yourself: "What if node-1 just... stops?"

_[Dramatic pause]_

The answer, as we discovered, is: **The entire cluster goes down.** No API server, no etcd, no nothing. It's like pulling the plug on your entire infrastructure.

So we set out on a mission: **Convert this single control plane into a highly available 3-node control plane.** Because with 3 nodes, you can lose one and still have quorum. Math is beautiful that way.

---

## Act II: The Plan

First things first: We needed a plan. A _real_ plan. Not just "let's wing it and see what happens" (though, let's be honest, that's sometimes how it goes).

The plan was elegant in its simplicity:

1. **Backup everything** (because we're not idiots)
2. **Convert node-2** from worker to control plane
3. **Convert node-3** from worker to control plane
4. **Test failover** by shutting down node-1
5. **Migrate storage** from local-path to Longhorn (for redundancy)
6. **Document everything** (because future us will thank present us)

Simple, right?

_[Narrator voice: It was not simple.]_

---

## Act III: The Conversion Begins

### Scene 1: Node-2, The First Convert

Node-2 was our first target. We drained it, stopped the k3s-agent, cleaned up the old state, and installed k3s as a server joining the existing cluster.

**First attempt:** Configuration mismatch. K3s on node-2 didn't match node-1's flags. `--disable-network-policy` was missing. Classic.

**Second attempt:** Version mismatch. We were using "v" instead of the actual version string. Because parsing version strings is apparently harder than rocket science.

**Third attempt:** Success! Node-2 joined as a control plane. We had 2-node HA! 🎉

But wait... with 2 nodes, if one goes down, we still lose quorum. We need 3.

### Scene 2: Node-3, The Stubborn One

Node-3 was... problematic. We tried. Oh, how we tried.

**Attempt 1:** Node-3 joined as an etcd learner but couldn't sync. TLS authentication handshake timeout. The certificates were there, the ports were open, but something wasn't clicking.

**Attempt 2:** Removed node-3 from etcd, cleaned everything, tried again. Same issue.

**Attempt 3:** Checked network connectivity. Ping worked. Ports were open. But the TLS handshake kept timing out.

**Attempt 4:** Tried promoting the learner manually. "Can only promote a learner member which is in sync with leader." Well, that's the problem, isn't it?

We're still working on node-3. It's currently stuck as an etcd learner, unable to sync. But we're not giving up. This is a marathon, not a sprint.

---

## Act IV: The Storage Migration Saga

While we were wrestling with node-3, we also decided to migrate storage from `local-path` to Longhorn. Because why do one thing at a time when you can do everything at once?

### The Migration

We had 4 PVCs to migrate:

- **Vault** (10Gi) - Your secrets, your life
- **Pi-hole** (2Gi) - Your DNS, your sanity
- **Grafana** (2Gi) - Your metrics, your insights
- **Prometheus** (8Gi) - Your data, your history

The migration itself was straightforward:

1. Scale down the apps
2. Delete old PVCs
3. Create new PVCs with Longhorn storage class
4. Scale back up

**What could go wrong?**

### The Longhorn Adventure

Everything. Everything could go wrong.

**Problem 1:** Longhorn admission webhook wasn't accessible. DNS was broken. CoreDNS was stuck on node-1 because node-1 ran out of pod IP addresses. Yes, really.

**Problem 2:** Longhorn CSI plugin couldn't register on node-3. More DNS issues.

**Problem 3:** Longhorn volumes stayed in "detached" state. The CSI attacher couldn't find nodes. "Node node-X.eldertree.local not found" - even though the nodes were right there.

**Problem 4:** Longhorn manager pods were crashing. Webhook timeouts. Backend API not responding.

We fixed DNS (restarted CoreDNS, moved it off node-1). We fixed Longhorn (restarted everything, cleaned up stale entries). We even fixed node-1's IP exhaustion (restarted k3s to release pod IPs).

But in the end, we hit a wall. Longhorn's internal networking was having issues. Pods couldn't reach services, even though the ports were open and DNS was working.

**The Decision:** We reverted to `local-path` storage. Sometimes, you have to know when to fold 'em. The apps needed to run, and we could revisit Longhorn later.

---

## Act V: The Vault Recovery

Oh, did I mention we also had to recover Vault? Because of course we did.

After all the node conversions and storage migrations, Vault was... not happy. It needed to be:

1. **Re-initialized** (because the data was on a new PVC)
2. **Unsealed** (because Vault is sealed by default)
3. **Restored** (because we had backups, thank goodness)

The unseal keys? Safely stored. The root token? Documented. The secrets? Restored from backup.

Vault is now running, unsealed, and all secrets are restored. Crisis averted.

---

## Act VI: The Current State

So where are we now?

**✅ What's Working:**

- 2-node HA control plane (node-1, node-2)
- All applications running on local-path storage
- Vault operational with all secrets restored
- CoreDNS fixed and working
- Cluster is stable and operational

**🔄 In Progress:**

- Node-3 control plane conversion (stuck as etcd learner, TLS sync issue)
- Longhorn storage migration (deferred due to networking issues)

**📊 The Math:**

- **2 nodes:** If one goes down, cluster loses quorum (needs majority = 2/2 = 100%)
- **3 nodes:** Can lose 1 node and maintain quorum (2/3 = 66.7% > 50%)

We're at 2 nodes. We want 3. We're working on it.

---

## Act VII: Lessons Learned (The Podcast Wrap-Up)

_[Reflective music starts]_

What did we learn today? So much. So, so much.

### Lesson 1: Always Backup First

We did this. It saved us. Multiple times. Backup everything. Always.

### Lesson 2: Configuration Matching Matters

When joining an HA control plane, every flag matters. `--disable-network-policy`, `--tls-san`, `--node-ip` - they all need to match. K3s is picky like that.

### Lesson 3: DNS is Everything

When DNS breaks, everything breaks. CoreDNS stuck? Longhorn can't find services. Pods can't resolve names. It's a cascade of failure. Fix DNS first.

### Lesson 4: Network IP Exhaustion is Real

Node-1 ran out of pod IP addresses. Yes, really. Flannel couldn't allocate more IPs. The solution? Restart k3s to release them. Sometimes the simple solution is the right one.

### Lesson 5: Know When to Pivot

Longhorn wasn't working. We spent hours debugging. Eventually, we reverted to local-path. The apps needed to run. We can revisit Longhorn later. Sometimes, you have to know when to fold 'em.

### Lesson 6: etcd is Fussy

etcd learners need to sync before they can be promoted. If they can't sync (TLS issues, network problems), they're stuck. We're still working on node-3's etcd sync issue. It's a work in progress.

### Lesson 7: Automation is Your Friend

We created Ansible playbooks for the conversion. They didn't work perfectly the first time, but they're getting better. Automation makes things repeatable. Repeatable is good.

---

## Act VIII: The Longhorn Breakthrough 🔥

**Date:** January 12, 2026

_[Dramatic music intensifies]_

Two days after achieving 3-node HA, we returned to the battlefield. Our mission: **Make Longhorn work for distributed storage with replication.**

Remember how we gave up on Longhorn before? Well, we're not quitters. We came back with fresh eyes and a new determination.

### Scene 1: The Symptoms

Longhorn was a mess:

- Managers crashing in `CrashLoopBackOff`
- Driver deployer stuck in `Init:0/1`
- Webhooks timing out with "context deadline exceeded"
- CSI drivers never deploying

The logs were screaming about webhook connectivity:

```
Failed to check endpoint https://longhorn-conversion-webhook.longhorn-system.svc:9501/v1/healthz
context deadline exceeded (Client.Timeout exceeded while awaiting headers)
```

### Scene 2: The Investigation

We dug deep. Really deep.

First, we tested from inside a debug pod:

```bash
nslookup longhorn-conversion-webhook.longhorn-system.svc
# Result: ;; connection timed out; no servers could be reached
```

**Wait, what?** DNS is timing out? But CoreDNS is running!

Then we checked cross-node connectivity:

```bash
# From node-1, ping CoreDNS on node-3
ping 10.42.4.69
# Result: 100% packet loss
```

**Cross-node pod networking is completely broken!**

But wait, the internal network (eth0) works fine:

```bash
# From node-1, ping node-3's internal IP
ping 10.0.0.3
# Result: 64 bytes from 10.0.0.3: icmp_seq=1 ttl=64 time=0.253 ms
```

### Scene 3: The Revelation 💡

The problem wasn't the nodes. The problem wasn't CoreDNS. The problem was...

**THE FIREWALL.**

We checked UFW on node-3:

```
Status: active
To                         Action      From
--                         ------      ----
OpenSSH                    ALLOW IN    Anywhere
2379/tcp                   ALLOW IN    Anywhere    # etcd
2380/tcp                   ALLOW IN    Anywhere    # etcd
```

See what's missing? **No rules for pod network traffic!**

The Flannel VXLAN overlay uses UDP port 8472. The pod network is 10.42.0.0/16. The service network is 10.43.0.0/16. None of these were allowed through the firewall!

Node-1 had these rules (from earlier troubleshooting). But node-2 and node-3 didn't. The packets were being silently dropped.

### Scene 4: The Fix

```bash
# On ALL nodes
sudo ufw allow from 10.0.0.0/24 comment 'k3s internal network'
sudo ufw allow from 10.42.0.0/16 comment 'k3s pod network'
sudo ufw allow from 10.43.0.0/16 comment 'k3s service network'
sudo ufw allow 8472/udp comment 'k3s flannel VXLAN'
```

Applied. Restarted k3s on all nodes to refresh the VXLAN tunnels.

And then...

```bash
# From node-1, ping CoreDNS on node-3
ping 10.42.4.69
# Result: 64 bytes from 10.42.4.69: icmp_seq=1 ttl=63 time=0.315 ms
```

**IT WORKS!** 🎉

### Scene 5: But Wait, There's More

With networking fixed, we reinstalled Longhorn 1.7.2. But it still wasn't working. The managers were complaining:

```
failed to list *v1beta2.Node: the server could not find the requested resource (get nodes.longhorn.io)
```

**The CRDs were missing!** The Helm chart had failed to create `engineimages.longhorn.io` and `nodes.longhorn.io`.

The fix:

```bash
# Apply the full Longhorn manifest to create missing CRDs
curl -sL https://raw.githubusercontent.com/longhorn/longhorn/v1.7.2/deploy/longhorn.yaml | kubectl apply -f -
```

CRDs created. Restarted the managers. And finally...

### Scene 6: Victory! 🏆

```
NAME                                                READY   STATUS    RESTARTS   AGE
csi-attacher-6b969989f5-2jrn2                       1/1     Running   0          93s
csi-provisioner-7dfb6db7b7-d4lsl                    1/1     Running   0          93s
engine-image-ei-51cc7b9c-6xtxd                      1/1     Running   0          2m12s
instance-manager-37d9358de907f15c5b5be60775443fc2   1/1     Running   0          102s
longhorn-csi-plugin-9m6p5                           3/3     Running   0          93s
longhorn-manager-2rrvz                              2/2     Running   0          2m17s
... (21 pods running!)
```

```
kubectl get nodes.longhorn.io -n longhorn-system
NAME                     READY   ALLOWSCHEDULING   SCHEDULABLE
node-1.eldertree.local   True    true              True
node-2.eldertree.local   True    true              True
node-3.eldertree.local   True    true              True
```

**All 3 nodes Ready. All 3 nodes Schedulable. Longhorn is ALIVE!**

And the best part:

```
kubectl get volumes.longhorn.io -n longhorn-system -o jsonpath='{.items[0].spec.numberOfReplicas}'
# Result: 3
```

**3 REPLICAS PER VOLUME!** Data is replicated across all 3 nodes. If any single node fails, the data survives.

---

## Act IX: The True High Availability Setup

_[Triumphant music plays]_

We did it. We actually did it.

| Component     | Status        | What It Means                    |
| ------------- | ------------- | -------------------------------- |
| Control Plane | 3-node HA     | API server survives node failure |
| etcd          | 3-node quorum | Data store survives node failure |
| kube-vip      | VIP active    | API access even when node-1 down |
| Longhorn      | 3 replicas    | Storage survives node failure    |

**If ANY single node goes offline:**

- ✅ Cluster API remains accessible (kube-vip failover)
- ✅ etcd maintains quorum (2/3 voting members)
- ✅ Storage data remains accessible (2/3 replicas)
- ✅ Pods can reschedule to healthy nodes
- ✅ Longhorn rebuilds replicas when node returns

This is TRUE high availability. Not "most things work if one node fails." **EVERYTHING works if one node fails.**

---

## 🎓 Final Lessons Learned

### Lesson 8: Firewall Rules Are Sneaky

The UFW firewall was silently dropping packets. No logs, no errors, just... gone. Always check firewall rules when debugging network issues.

### Lesson 9: Flannel VXLAN Needs Port 8472

The overlay network uses UDP 8472 for VXLAN encapsulation. Block this port, and cross-node pod communication dies silently.

### Lesson 10: Helm Charts Can Fail Silently

The Helm chart didn't create all the CRDs. No error, just missing resources. Always verify CRDs exist after installation.

### Lesson 11: Never Give Up

We gave up on Longhorn on January 10. We came back on January 12. Fresh eyes, fresh approach, and we found the real problem. Sometimes you need to step away and come back.

---

## 🎬 Closing Thoughts

_[Triumphant podcast outro music fades in]_

What a journey. What. A. Journey.

We started with a single control plane and a dream. We ended with a fully redundant, highly available Kubernetes cluster that can survive the loss of any single node.

**The scorecard:**

- ✅ 3-node HA control plane
- ✅ etcd with quorum
- ✅ kube-vip for API failover
- ✅ Longhorn with 3-replica distributed storage
- ✅ All applications running and healthy
- ✅ Vault secured and unsealed
- ✅ Complete documentation

This is what we dreamed of. This is what we built.

_[Pause for dramatic effect]_

The lesson? **Never give up.** When Longhorn wasn't working, we stepped back. When it still wasn't working, we dug deeper. When we found the firewall issue, we fixed it. When the CRDs were missing, we applied them manually.

Problem by problem. Layer by layer. Until it worked.

That's what building infrastructure is all about. It's not about getting it right the first time. It's about getting it right _eventually_. And then documenting the hell out of it so you never have to figure it out again.

**Final thoughts:**

To future us, reading this at 3am when something breaks: **Check the firewall first.** Then DNS. Then certificates. In that order.

To anyone else on this journey: It's possible. It's hard, but it's possible. Three Raspberry Pis, some patience, and a lot of debugging can give you a production-grade, highly available Kubernetes cluster.

Is it overkill for a home lab? Maybe. But when node-1 goes down at 2am and everything keeps working? That's not overkill. That's peace of mind.

_[Podcast outro music swells]_

Until next time, keep your clusters redundant and your firewalls open (to the right ports).

**Outro:** This has been "Building Eldertree" - where we document the real journey of self-hosted Kubernetes, one firewall rule at a time.

🎉 **THE END... FOR NOW** 🎉

---

## 📝 Technical Details (For the Nerds)

### Vault Unseal Keys

```
Key 1: <STORED_SECURELY>
Key 2: <STORED_SECURELY>
Key 3: <STORED_SECURELY>
Key 4: <STORED_SECURELY>
Key 5: <STORED_SECURELY>
Root Token: <STORED_SECURELY>
```

> **Note:** Actual keys stored securely offline. Never commit real secrets to git!

### Current Cluster State (Updated January 12, 2026)

- **Control Plane Nodes:** node-1, node-2, node-3 (3-node HA ✅)
- **Worker Nodes:** None (all nodes are control plane)
- **etcd Members:** 3 voting members (all nodes, no learners)
- **Storage:** Longhorn with 3 replicas per volume ✅
- **API Access:** kube-vip VIP at 192.168.2.100 ✅
- **Status:** ✅ TRUE HA - Can lose any 1 node and maintain full operation

### The Breakthrough: Firewall Rules!

After hours of debugging TLS handshake timeouts, we discovered the root cause: **UFW firewall was blocking etcd peer connections!**

Node-3's etcd was listening on ports 2379 and 2380, but the firewall was silently blocking incoming connections from node-1 and node-2. The TLS handshake was timing out because the connection couldn't even be established.

**The Fix (etcd):**

```bash
# On all control plane nodes
sudo ufw allow 2379/tcp comment 'etcd client'
sudo ufw allow 2380/tcp comment 'etcd peer'
sudo ufw allow from 10.0.0.0/8 to any port 2379 comment 'etcd client from cluster'
sudo ufw allow from 10.0.0.0/8 to any port 2380 comment 'etcd peer from cluster'
```

Within seconds of opening the firewall, node-3's etcd synced and became a voting member. The cluster went from 2-node HA to full 3-node HA!

**The Fix (k3s networking - discovered January 12):**

```bash
# On ALL nodes - CRITICAL for cross-node pod communication!
sudo ufw allow from 10.0.0.0/24 comment 'k3s internal network'
sudo ufw allow from 10.42.0.0/16 comment 'k3s pod network'
sudo ufw allow from 10.43.0.0/16 comment 'k3s service network'
sudo ufw allow 8472/udp comment 'k3s flannel VXLAN'
```

Without these rules, the Flannel VXLAN overlay can't function, and pods on different nodes can't communicate. This broke DNS, services, and Longhorn.

**Lesson Learned:** Always check firewall rules when troubleshooting network connectivity issues, even if ports appear "open" in netstat/ss. UFW can block connections even if the service is listening. Kubernetes networking requires specific ports for the CNI to function!

### Next Steps

1. ✅ ~~Resolve node-3 etcd TLS sync issue~~ - **DONE! (Firewall was the culprit)**
2. ✅ ~~Complete 3-node HA control plane~~ - **DONE!**
3. ✅ ~~Test failover scenarios~~ - **DONE! (Cluster remains operational with 1 node down)**
4. ✅ ~~Revisit Longhorn storage migration~~ - **DONE! (Fixed firewall + CRDs, Longhorn operational)**
5. ✅ ~~Document HA setup and troubleshooting~~ - **DONE! (This post + HA_SETUP.md + LONGHORN_FIX_2026-01-12.md)**
6. ✅ ~~Set up kube-vip for API failover~~ - **DONE! (VIP at 192.168.2.100)**
7. ✅ ~~Update Ansible playbooks with firewall rules~~ - **DONE! (install-k3s.yml updated)**

**ALL GOALS ACHIEVED! 🏆**

### HA Failover Test Results 🎯

We tested the HA setup by shutting down node-3. Results:

- ✅ Cluster detected node failure within 60 seconds
- ✅ API server remained accessible (0 downtime)
- ✅ etcd quorum maintained (2/3 = 66.7% > 50%)
- ✅ All cluster operations functional (list, scale, etc.)
- ✅ Pods continued running on remaining nodes

**The 3-node HA control plane works perfectly!** See [HA_FAILOVER_TEST_REPORT.md](../docs/HA_FAILOVER_TEST_REPORT.md) for full test details.

### Longhorn Configuration (January 12, 2026)

Longhorn 1.7.2 is now fully operational:

```bash
# Install command used
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --version 1.7.2 \
  --set csi.kubeletRootDir="/var/lib/kubelet" \
  --set defaultSettings.defaultDataPath="/var/lib/longhorn" \
  --set persistence.defaultClassReplicaCount=2
```

**Current Status:**

- 21 Longhorn pods running
- 3 nodes Ready and Schedulable
- 3 replicas per volume (configurable)
- CSI drivers deployed and functional

See [LONGHORN_FIX_2026-01-12.md](../docs/LONGHORN_FIX_2026-01-12.md) for detailed troubleshooting notes.

---

## 📚 Related Documentation

- [HA_SETUP.md](../docs/HA_SETUP.md) - High Availability setup guide
- [HA_FAILOVER_TEST_REPORT.md](../docs/HA_FAILOVER_TEST_REPORT.md) - Failover test results
- [LONGHORN_FIX_2026-01-12.md](../docs/LONGHORN_FIX_2026-01-12.md) - Longhorn troubleshooting
- [NETWORK_CONFIGURATION_BEST_PRACTICES.md](../docs/NETWORK_CONFIGURATION_BEST_PRACTICES.md) - Network setup
- [PREVENT_NETWORK_ISSUES.md](../docs/PREVENT_NETWORK_ISSUES.md) - Preventing issues

---

## Act X: Vault HA - The Final Piece 🔐

**Date:** January 13, 2026

_[The saga continues with the final piece of true HA]_

After achieving 3-node HA for the control plane and Longhorn storage, we had one remaining single point of failure: **Vault**. Running in standalone mode with 1 replica and local-path storage, if the node hosting Vault failed, all secrets management would go down.

### The Problem

```
vault-0: Running on node-1 with local-path PVC
         -> If node-1 dies, Vault dies
         -> If Vault dies, External Secrets stop syncing
         -> If External Secrets stop, apps lose their secrets
```

### The Solution: Vault HA with Raft

We migrated Vault from standalone mode to full HA with:

- **3 replicas** (one per node)
- **Raft integrated storage** (data replicated across all nodes)
- **Longhorn PVCs** (each pod has its own replicated storage)
- **Kubernetes auto-unseal** (unseal keys stored in K8s secret)

### Migration Process

1. **Backup all secrets** using existing backup script
2. **Update HelmRelease** to enable HA mode:

```yaml
server:
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
      setNodeId: true
  dataStorage:
    storageClass: longhorn  # Replicated storage
```

3. **Delete old StatefulSet and PVC** (local-path was pinned to node-1)
4. **Let Flux deploy new HA configuration**
5. **Initialize new Vault cluster** (generates new unseal keys)
6. **Unseal all 3 pods**
7. **Restore secrets from backup**
8. **Update External Secrets vault-token**

### Failover Test Results 🎯

We deleted vault-0 (the leader) to test failover:

```
Before: vault-0 = leader, vault-1 = standby, vault-2 = standby
After:  vault-0 = (deleted), vault-1 = LEADER, vault-2 = standby
        -> New leader elected in < 15 seconds!
        -> vault-0 restarted and rejoined as follower
```

**Results:**
- ✅ New leader elected automatically (vault-1 took over)
- ✅ No data loss (Raft replication preserved all secrets)
- ✅ External Secrets continued syncing from new leader
- ✅ Cluster returned to healthy state after vault-0 recovery
- ✅ Failure Tolerance = 1 (can lose 1 node and maintain quorum)

### Final HA Status

| Component | Status | Failure Tolerance |
|-----------|--------|-------------------|
| Control Plane | 3-node HA | 1 node |
| etcd | 3-node quorum | 1 node |
| kube-vip | VIP failover | 1 node |
| Longhorn Storage | 3 replicas | 1 node |
| **Vault** | **3-node HA Raft** | **1 node** |

### Scripts Created

- `scripts/operations/init-vault-ha.sh` - Initialize HA cluster
- `scripts/operations/unseal-vault.sh` - Updated for multi-pod unsealing

### Related Documentation

- [clusters/eldertree/secrets-management/vault/helmrelease.yaml](../clusters/eldertree/secrets-management/vault/helmrelease.yaml) - HA configuration

---

## 🏆 TRUE HIGH AVAILABILITY ACHIEVED

**Now ANY single node in the eldertree cluster can fail, and EVERYTHING keeps running:**

- ✅ Control plane survives (etcd quorum maintained)
- ✅ API server accessible (kube-vip failover)
- ✅ Storage survives (Longhorn replication)
- ✅ Secrets survive (Vault Raft replication)
- ✅ Pods reschedule to healthy nodes
- ✅ External Secrets continue syncing

This is what true high availability looks like. 🎉

---

_End of Episode - Complete Victory Edition! 🎉🏆_

**Final Status:** TRUE HIGH AVAILABILITY ACHIEVED ✅
