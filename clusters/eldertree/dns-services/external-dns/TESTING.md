# Testing External-DNS with BIND Backend

## Prerequisites

1. Flux has deployed external-dns and updated Pi-hole with BIND sidecar
2. All pods are running

## Verify Deployment

```bash
# Check external-dns pod
kubectl get pods -n external-dns

# Check Pi-hole pod (should have 2 containers: pihole and bind)
kubectl get pods -n pihole
kubectl describe pod -n pihole -l app=pihole

# Check BIND is listening
kubectl exec -n pihole deployment/pihole -c bind -- netstat -tuln | grep 5353
```

## Check External-DNS Logs

```bash
# Watch external-dns logs
kubectl logs -n external-dns deployment/external-dns -f

# Should see:
# - "Connected to 192.168.2.83:5353"
# - "RFC2136 update successful"
```

## Test DNS Record Creation

### 1. Create a Test Ingress

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-service
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: selfsigned-cluster-issuer
spec:
  tls:
  - hosts:
    - test.eldertree.local
    secretName: test-tls
  rules:
  - host: test.eldertree.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-service
            port:
              number: 80
EOF
```

### 2. Verify DNS Record Created

```bash
# Check external-dns logs for record creation
kubectl logs -n external-dns deployment/external-dns | grep test.eldertree.local

# Query BIND directly
dig @192.168.2.83 -p 5353 test.eldertree.local

# Query via Pi-hole (should forward to BIND)
dig @192.168.2.83 test.eldertree.local
nslookup test.eldertree.local 192.168.2.83
```

### 3. Verify DNS Resolution

```bash
# Should resolve to 192.168.2.83
nslookup test.eldertree.local 192.168.2.83
dig @192.168.2.83 test.eldertree.local
```

## Test DNS Record Deletion

```bash
# Delete the Ingress
kubectl delete ingress test-service

# Check external-dns logs for record deletion
kubectl logs -n external-dns deployment/external-dns | grep "deleted"

# Verify DNS record removed
dig @192.168.2.83 -p 5353 test.eldertree.local
# Should return NXDOMAIN or no answer
```

## Troubleshooting

### BIND Not Starting

```bash
# Check BIND logs
kubectl logs -n pihole deployment/pihole -c bind

# Check BIND config
kubectl exec -n pihole deployment/pihole -c bind -- cat /etc/named/named.conf

# Verify zone file exists
kubectl exec -n pihole deployment/pihole -c bind -- ls -la /var/named/
```

### External-DNS Can't Connect

```bash
# Test connectivity from external-dns pod
kubectl exec -n external-dns deployment/external-dns -- nc -zv 192.168.2.83 5353

# Check BIND is accessible
kubectl exec -n pihole deployment/pihole -c bind -- netstat -tuln | grep 5353
```

### DNS Not Resolving

```bash
# Check dnsmasq config
kubectl exec -n pihole deployment/pihole -c pihole -- cat /etc/dnsmasq.d/06-bind-backend.conf

# Test BIND directly
dig @192.168.2.83 -p 5353 test.eldertree.local

# Test dnsmasq forwarding
dig @192.168.2.83 test.eldertree.local
```

### TSIG Authentication Issues

```bash
# Verify TSIG key matches
kubectl get secret -n external-dns external-dns-tsig-secret -o jsonpath='{.data.tsig-secret}' | base64 -d
kubectl exec -n pihole deployment/pihole -c bind -- grep secret /etc/named/named.conf

# Keys should match (after base64 decode)
```

