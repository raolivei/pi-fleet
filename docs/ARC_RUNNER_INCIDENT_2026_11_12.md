# ARC queue and node review — 2026-11-12

## Observed incident

Ollie run `42865001882` was queued while its ephemeral runner on node-3 had
spent about 38 hours in `Init:ImagePullBackOff`. Kubelet events identified
`lookup ghcr.io: Try again` while pulling the Actions runner image. Node-3
remained reachable through the internal Ethernet network from node-2, but its
management address and internet access were failing from the Mac.

Rafael restarted the nodes during diagnosis. After node-3 rebooted, gateway
access, GHCR DNS/HTTPS, and pod access to the GitHub API succeeded. Kubelet
pulled the runner image, ARC removed the stale ephemeral runner, and fresh
runners registered online and accepted jobs. Existing Ollie build jobs then
completed successfully. A later run, `43258502928`, was observed in progress.
The reboot cleared the observed network failure; it does not establish or fix
the underlying cause of the recurring connectivity failure.

## Routing and scheduling review

- The installed ARC 0.14.2 chart renders `scaleSetLabels` as
  `spec.runnerScaleSetLabels`. The live Ollie scale set advertises
  `[self-hosted]`; its existing workflow selector is correct.
- Preserve unique scale-set names. They also identify Kubernetes resources in
  the shared `arc-runners` namespace.
- Node-1 has the intended `unstable` label and
  `eldertree.xyz/prefer-stable-nodes=true:PreferNoSchedule` taint. Node-2/3 have
  the intended `stable` label and no blocking taints.
- `PreferNoSchedule` is a scheduling preference. Runners/listeners can use
  node-1 for overflow without adding a broad toleration or removing the taint.
- The controller is explicitly restricted to stable nodes. Runner templates
  retain soft spreading and overflow capacity.

## Corrected resource configuration

With Kubernetes 1.35, ARC's built-in DinD mode emits a restartable init
container. The former `template.spec.containers[name=dind].resources` blocks
were ignored. The live injected Docker daemon had no requests or limits.
Listener pods also had no requests/limits, and most were concentrated on
node-3.

Use namespace LimitRanges to default generated containers without copying the
chart's DinD implementation. A shared listener template patch adds soft stable
node preference and hostname spreading. Explicit runner/controller resources
continue to take precedence. Defaults affect newly admitted pods; they do not
restart running jobs. These changes bound resources, but do not impose a
cluster-wide runner concurrency limit or repair host Wi-Fi connectivity.

See [ARC_RUNNERS.md](ARC_RUNNERS.md) for resource budgets and deployment details.

## Remaining infrastructure observations

During recovery, the management API VIP timed out intermittently while direct
node-2 and node-3 API readiness probes passed. Kube-vip logs showed API lease
renewal timeouts followed by leadership loss/restarts. Its configured lease
duration/renewal deadline were 5/3 seconds.

Node-1's SSH connection closed and its etcd peer port refused connections;
the API still reported an older Ready condition. Do not treat that reported
condition as proof that the host completed recovery. Further node/VIP checks
are required after all restarts finish.

A running `swimto-web` pod was observed on node-1 even though its current
required affinity excludes the `unstable` tier. Node-1's recorded k3s startup
arguments include a `node-tier=stable` label, conflicting with the scheduling
reconciler's declared policy. Inspect the actual node startup configuration
when host access recovers before changing it; the annotation alone does not
prove which current file or command owns that setting. Do not evict workloads
while node recovery remains uncertain.

Prometheus was reachable through the Kubernetes service proxy: 55 of 56 scrape
targets were up in the observed sample. The down target was Traefik metrics;
this observation alone does not establish an ingress outage.
