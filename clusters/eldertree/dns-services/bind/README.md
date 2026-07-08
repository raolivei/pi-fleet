# BIND9 — LAN DNS for eldertree.local

Replaces Pi-hole (adblock unused). Single-container authoritative DNS + recursion.

- **VIP:** `192.168.2.201` (router DNS, unchanged)
- **RFC2136:** external-dns → `bind9.bind.svc.cluster.local:53`
- **Issue:** [pi-fleet#232](https://github.com/raolivei/pi-fleet/issues/232)

```bash
kubectl get pods,svc -n bind
dig @192.168.2.201 grafana.eldertree.local +short
```
