# Blackbox Exporter: Synthetic (External) HTTP Monitoring

This document explains **what the [Prometheus Blackbox exporter](https://github.com/prometheus/blackbox_exporter) is for** on Eldertree, how it relates to the rest of the stack, and where the manifests live.

## What problem it solves

Eldertree already has strong **in-cluster** signals: pod `up`/`kube_` metrics, Service endpoints, cAdvisor, Traefik’s own metrics, and per-app `/metrics` where annotated. None of that answers, by itself, the SRE question:

*“From the same perspective as a user, over HTTPS, with DNS, TLS, ingress, and tunnels in the path — does the URL work?”*

**Blackbox fills that gap** by running **synthetic HTTP(S) probes** from *inside* the cluster (or wherever the exporter runs). Prometheus scrapes the exporter; the exporter fetches the target URL and reports metrics such as:

| Metric (examples) | Meaning |
|-------------------|--------|
| `probe_success` | `1` if the probe’s module conditions passed (e.g. HTTP 2xx), `0` otherwise |
| `probe_http_status_code` | Status code of the last probe |
| `probe_duration_seconds` | End-to-end probe latency |

So you can alert on “this public hostname is not returning 2xx” or “probe failed entirely,” even when the Kubernetes `Deployment` still shows ready pods.

**Blackbox is not a substitute for** OpenTelemetry, distributed tracing, or application log pipelines: it is **synthetic reachability/availability** to URLs (and optionally TCP/ICMP, depending on modules), not a trace or log system.

**Blackbox is complementary to** in-cluster `up` metrics: a service can be “up” on the port while a misconfigured ingress, cert, or DNS name still breaks the *external* user path.

## How Eldertree is wired

1. **Blackbox exporter** runs in the `observability` namespace (see `clusters/eldertree/observability/blackbox-exporter.yaml`).
2. **Static scrape config** in the same kustomization tells Prometheus to scrape Blackbox in **prober** mode: targets are the real URLs, the `__address__` for the scrape is the Blackbox pod, with `__param_target` set to each URL. See `clusters/eldertree/observability/blackbox-scrape-config.yaml` for the live target list (public sites and internal UIs, with a separate job for `https_2xx` vs. custom CA / internal cert checks).
3. **Alerting** is defined in the `monitoring-stack` Helm values: the `BlackboxProbeFailing` alert fires when `probe_success` is `0` for Blackbox’s scrape jobs. See `helm/monitoring-stack/values.yaml` (and `DASHBOARDS.md` in that chart for the on-call view).

## What we did the same day (context)

In the same observability pass we also: scraped Traefik’s own Prometheus endpoint (ingress-level truth), fixed Grafana’s dashboard sidecar to only read ConfigMaps in `observability` (so third-party charts don’t pollute Grafana), added optional Loki + Promtail + a Grafana Loki datasource, and shipped an **Eldertree Ops Home** dashboard that includes Blackbox and other high-signal rows. The operational “map” of dashboards is [`helm/monitoring-stack/DASHBOARDS.md`](../helm/monitoring-stack/DASHBOARDS.md).

## Adding a new public URL to probe

1. Add the `https://…` target to the appropriate `static_configs.targets` in [`helm/monitoring-stack/values.yaml`](../helm/monitoring-stack/values.yaml) under `prometheus.scrapeConfigs` (blackbox jobs) — keep in sync with any `blackbox-scrape-config` reference copy you keep locally.
2. Reconcile/apply; confirm the target appears under **Status → Targets** in Prometheus for `blackbox-https` / `blackbox-https-ca`.
3. Optionally add a row or stat on **Eldertree Ops Home** in Grafana to surface the new instance.

---

**TL;DR:** Blackbox = **synthetic external HTTPS checks** with `probe_success` in Prometheus, plus alerts — not a replacement for pod health or for OTel/Loki, but a necessary third angle for “can users actually reach it?”
