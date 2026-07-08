# bind9 (Eldertree LAN DNS)

Authoritative DNS for `eldertree.local` with RFC2136 dynamic updates from external-dns.

Replaces the Pi-hole + BIND sidecar stack. Listens on port **53** with LoadBalancer VIP `192.168.2.201` (kube-vip).

## Requirements

- TSIG secret synced to namespace: `bind-tsig-secret` (from Vault `secret/pi-fleet/external-dns/tsig-secret`)
- external-dns RFC2136 host: `bind9.bind.svc.cluster.local`, port `53`

## Verify

```bash
kubectl get pods,svc -n bind
dig @192.168.2.201 grafana.eldertree.local +short
kubectl logs -n external-dns deploy/external-dns --tail=20
```
