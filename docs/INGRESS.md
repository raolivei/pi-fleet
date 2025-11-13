# Ingress, SSL Certificates and Automatic DNS

Complete guide on configuring and using Traefik Ingress Controller, Cert-Manager, and ExternalDNS in the k3s cluster.

## Overview

The cluster uses three main components to manage HTTP/HTTPS traffic and DNS:

1. **Traefik** - Ingress Controller (pre-installed with k3s)
2. **Cert-Manager** - Automatic SSL/TLS certificate management
3. **ExternalDNS** - Automatic DNS record creation for ingress resources

## Traefik Ingress Controller

### Default k3s Configuration

k3s automatically installs Traefik as the default Ingress Controller in the `kube-system` namespace. No additional configuration is required for basic usage.

**Features:**

- IngressClass: `traefik`
- HTTP Port: 80
- HTTPS Port: 443
- Configuration via Kubernetes Ingress resources

### Check Status

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check Traefik pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

# Check Traefik service
kubectl get svc -n kube-system traefik

# Check IngressClass
kubectl get ingressclass traefik
```

### Create an Ingress

Basic example of an Ingress using Traefik:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-service
  namespace: my-namespace
  annotations:
    cert-manager.io/cluster-issuer: selfsigned-cluster-issuer
spec:
  ingressClassName: traefik
  rules:
    - host: myservice.eldertree.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
  tls:
    - hosts:
        - myservice.eldertree.local
      secretName: myservice-tls
```

### Useful Traefik Annotations

```yaml
metadata:
  annotations:
    # Custom headers
    traefik.ingress.kubernetes.io/headers.customrequestheaders: X-Forwarded-Proto=https

    # Redirect HTTP to HTTPS
    traefik.ingress.kubernetes.io/redirect-to: https

    # Authentication middleware (if configured)
    traefik.ingress.kubernetes.io/router.middlewares: default-auth@kubernetescrd
```

### Advanced Configuration

For custom Traefik configurations (middlewares, rate limiting, etc.), you can create Traefik `IngressRoute` resources or modify the Traefik ConfigMap in the `kube-system` namespace.

**Warning:** Modifying the default k3s Traefik may be overwritten during updates. Consider using a custom Traefik installation if you need specific configurations.

## Cert-Manager

### Overview

Cert-Manager automatically manages SSL/TLS certificates for cluster ingress resources. It watches Ingress resources and creates certificates automatically when it detects appropriate annotations.

### Installation

Cert-Manager is installed via FluxCD HelmRelease:

- **Namespace**: `cert-manager`
- **HelmRelease**: `clusters/eldertree/infrastructure/cert-manager/helmrelease.yaml`
- **Chart**: `jetstack/cert-manager` (v1.16.2)

### Check Status

```bash
# Check Cert-Manager pods
kubectl get pods -n cert-manager

# Check ClusterIssuers
kubectl get clusterissuer

# Check certificates
kubectl get certificates -A

# Check CertificateRequests
kubectl get certificaterequests -A
```

### Available ClusterIssuers

#### Self-Signed Issuer

Issuer for development/testing that generates self-signed certificates:

- **Name**: `selfsigned-cluster-issuer`
- **Type**: Self-signed
- **Status**: ✅ Active

**Usage:**

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: selfsigned-cluster-issuer
```

**Limitation:** Browsers will show an untrusted certificate warning. Use only for internal development.

#### ACME Issuer (Let's Encrypt)

Issuer for valid public certificates via Let's Encrypt:

- **Name**: `letsencrypt-prod` (when enabled)
- **Type**: ACME HTTP-01 Challenge
- **Status**: ⚠️ Disabled (requires public domain and additional configuration)

**Enable:**
Edit `helm/cert-manager-issuers/values.yaml`:

```yaml
acme:
  enabled: true
  email: "your-email@example.com"
  server: https://acme-v02.api.letsencrypt.org/directory
  name: letsencrypt-prod
```

**Usage:**

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
```

### Create Certificate Automatically

Cert-Manager creates certificates automatically when you create an Ingress with the correct annotations:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-service
  namespace: my-namespace
  annotations:
    cert-manager.io/cluster-issuer: selfsigned-cluster-issuer
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - myservice.eldertree.local
      secretName: myservice-tls # Cert-Manager will create this secret
  rules:
    - host: myservice.eldertree.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

### Verify Certificate

```bash
# Check certificate secret
kubectl get secret myservice-tls -n my-namespace

# View certificate details
kubectl describe certificate myservice-tls -n my-namespace

# Check certificate content (base64)
kubectl get secret myservice-tls -n my-namespace -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

### Troubleshooting

**Certificate is not being created:**

```bash
# Check Cert-Manager logs
kubectl logs -n cert-manager deployment/cert-manager
kubectl logs -n cert-manager deployment/cert-manager-webhook
kubectl logs -n cert-manager deployment/cert-manager-cainjector

# Check events
kubectl describe certificate myservice-tls -n my-namespace
kubectl describe certificaterequest -n my-namespace
```

**Common error:** Cert-Manager cannot create certificate because the ClusterIssuer doesn't exist or has incorrect name in the annotation.

## ExternalDNS

### Overview

ExternalDNS monitors Ingress and Service resources in the cluster and automatically creates/updates DNS records in the configured DNS server (Pi-hole/BIND via RFC2136).

### Current Configuration

- **Namespace**: `external-dns`
- **Provider**: RFC2136 (BIND)
- **Domain**: `eldertree.local`
- **HelmRelease**: `clusters/eldertree/infrastructure/external-dns/helmrelease.yaml`

### Architecture

ExternalDNS connects to BIND (Pi-hole sidecar) via RFC2136 protocol to create DNS records:

1. ExternalDNS watches Ingress resources in the cluster
2. When it detects a new Ingress with hostname `*.eldertree.local`, it creates DNS record via RFC2136
3. BIND manages the `eldertree.local` zone and accepts authenticated updates with TSIG
4. dnsmasq (Pi-hole) queries BIND to resolve `*.eldertree.local`

### Check Status

```bash
# Check ExternalDNS pod
kubectl get pods -n external-dns

# View ExternalDNS logs
kubectl logs -n external-dns deployment/external-dns

# Check created DNS records
kubectl logs -n external-dns deployment/external-dns | grep "Creating"
```

### How It Works

ExternalDNS automatically detects ingress resources with hostnames in the configured domain (`eldertree.local`). No special annotation is required - just create the Ingress with the correct hostname.

**Example:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-service
  namespace: my-namespace
spec:
  ingressClassName: traefik
  rules:
    - host: myservice.eldertree.local # ExternalDNS automatically detects this
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

ExternalDNS will automatically create the DNS record `myservice.eldertree.local` pointing to the Traefik IP (192.168.2.83).

### Verify DNS Record

```bash
# Query DNS directly on Pi-hole
nslookup myservice.eldertree.local 192.168.2.83

# Or using dig
dig @192.168.2.83 myservice.eldertree.local
```

### Configuration

ExternalDNS configuration is in `clusters/eldertree/infrastructure/external-dns/helmrelease.yaml`:

- **Provider**: `rfc2136`
- **Zone**: `eldertree.local`
- **TSIG Key**: Stored in secret `external-dns-tsig-secret`
- **Policy**: `sync` (creates/updates/deletes records)
- **Registry**: `txt` (tracks ownership via TXT records)

### Troubleshooting

**DNS records are not being created:**

```bash
# Check ExternalDNS logs
kubectl logs -n external-dns deployment/external-dns

# Verify TSIG key is correct
kubectl get secret external-dns-tsig-secret -n external-dns

# Check connectivity to BIND
kubectl exec -n external-dns deployment/external-dns -- nslookup eldertree.local 192.168.2.83
```

**Common error:** Incorrect TSIG key or BIND is not accepting RFC2136 updates.

**HelmRepository DNS resolution issues:**

If ExternalDNS HelmRelease fails to deploy because the HelmRepository cannot fetch the chart index (DNS resolution errors), this is usually caused by a circular DNS dependency:

1. CoreDNS forwards queries to Pi-hole
2. Pi-hole uses CoreDNS for its own DNS resolution (`dnsPolicy: ClusterFirst`)
3. This creates a loop preventing external domain resolution

**Solution:** Ensure Pi-hole can resolve external domains by:

- Verifying Pi-hole has upstream DNS servers configured (8.8.8.8, 1.1.1.1)
- Checking Pi-hole can resolve external domains: `kubectl exec -n pihole deployment/pihole -c pihole -- nslookup google.com 8.8.8.8`
- If needed, restart Pi-hole pod to reload DNS configuration
- Force HelmRepository reconciliation: `kubectl patch helmrepository -n flux-system external-dns --type merge -p '{"metadata":{"annotations":{"fluxcd.io/reconcile":"now"}}}'`

## Complete Flow: Create a New Service

Complete example of creating a service with Ingress, SSL certificate, and automatic DNS:

### 1. Create Deployment and Service

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: app
          image: nginx:latest
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: my-namespace
spec:
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 80
```

### 2. Create Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-namespace
  annotations:
    cert-manager.io/cluster-issuer: selfsigned-cluster-issuer
spec:
  ingressClassName: traefik
  rules:
    - host: my-app.eldertree.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
  tls:
    - hosts:
        - my-app.eldertree.local
      secretName: my-app-tls
```

### 3. What Happens Automatically

1. **Traefik** detects the Ingress and configures routing
2. **Cert-Manager** detects the annotation and creates SSL certificate
3. **ExternalDNS** detects the hostname and creates DNS record

### 4. Verify Everything Working

```bash
# Check Ingress
kubectl get ingress -n my-namespace

# Check certificate
kubectl get certificate -n my-namespace
kubectl get secret my-app-tls -n my-namespace

# Check DNS
nslookup my-app.eldertree.local 192.168.2.83

# Test access
curl -k https://my-app.eldertree.local
```

## Patterns and Best Practices

### Annotation Pattern

Always use these annotations on ingress resources that need SSL certificates:

```yaml
annotations:
  cert-manager.io/cluster-issuer: selfsigned-cluster-issuer # or letsencrypt-prod
```

### IngressClassName Pattern

Always specify the IngressClass:

```yaml
spec:
  ingressClassName: traefik
```

### TLS Secret Naming

Use the pattern `{service-name}-tls`:

```yaml
tls:
  - hosts:
      - myservice.eldertree.local
    secretName: myservice-tls
```

### Domains

- **Development/Internal**: Use `*.eldertree.local` (managed by ExternalDNS + Pi-hole)
- **Production/Public**: Use public domain with ACME issuer (when configured)

## Useful Commands

```bash
# List all ingress resources
kubectl get ingress -A

# List all certificates
kubectl get certificates -A

# List all ClusterIssuers
kubectl get clusterissuer

# View events related to certificates
kubectl get events -A --field-selector involvedObject.kind=Certificate

# View ExternalDNS logs in real-time
kubectl logs -n external-dns -f deployment/external-dns

# Test DNS resolution
nslookup <hostname>.eldertree.local 192.168.2.83
```

## References

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Cert-Manager Documentation](https://cert-manager.io/docs/)
- [ExternalDNS Documentation](https://github.com/kubernetes-sigs/external-dns)
- [Kubernetes Ingress Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)
