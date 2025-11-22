# Tool Organization Guide

This document explains how infrastructure code is organized across Ansible, Terraform, and Helm.

## Principles

- **Ansible**: System configuration, operational tasks, and secret management
- **Terraform**: Infrastructure provisioning (Cloudflare DNS, Tunnels)
- **Helm**: Kubernetes application deployment and configuration

## Ansible

**Purpose**: System configuration and operational tasks

**Responsibilities**:
- System configuration (users, hostname, network)
- Package installation
- k3s cluster installation
- FluxCD GitOps bootstrap
- DNS configuration (local /etc/hosts)
- Secret management (Vault operations)
- Operational tasks (monitoring setup, etc.)

**Location**: `ansible/playbooks/`

**Key Playbooks**:
- `setup-system.yml` - Complete system setup
- `install-k3s.yml` - k3s cluster installation
- `bootstrap-flux.yml` - FluxCD GitOps bootstrap
- `configure-dns.yml` - DNS configuration
- `manage-secrets.yml` - Secret management in Vault

## Terraform

**Purpose**: Infrastructure provisioning

**Responsibilities**:
- Cloudflare DNS records (A, CNAME)
- Cloudflare Tunnel creation and ingress configuration
- Infrastructure state management

**What Terraform Does NOT Do**:
- ❌ TLS certificate generation (handled by cert-manager via Helm)
- ❌ Kubernetes resource management (handled by Helm/FluxCD)
- ❌ System configuration (handled by Ansible)

**Location**: `terraform/`

**Key Files**:
- `cloudflare.tf` - Cloudflare DNS and Tunnel resources
- `main.tf` - Main Terraform configuration
- `variables.tf` - Input variables
- `outputs.tf` - Output values

**Usage**:
```bash
cd terraform
./run-terraform.sh plan
./run-terraform.sh apply
```

## Helm

**Purpose**: Kubernetes application deployment and configuration

**Responsibilities**:
- Custom Helm charts for cluster components
- cert-manager issuers (TLS certificate management)
- Monitoring stack (Prometheus + Grafana)
- KEDA scaled objects
- Application configuration via values.yaml

**What Helm Does**:
- ✅ TLS certificate management (via cert-manager)
- ✅ Kubernetes resource templating
- ✅ Application configuration management
- ✅ Dependency management

**Location**: `helm/`

**Key Charts**:
- `cert-manager-issuers/` - ClusterIssuers for TLS
- `monitoring-stack/` - Prometheus + Grafana
- `keda-scaledobjects/` - KEDA autoscaling configuration

## Decision Matrix

### Where Should This Go?

| Task | Tool | Reason |
|------|------|--------|
| Install k3s on Pi | Ansible | System configuration |
| Create Cloudflare DNS record | Terraform | Infrastructure provisioning |
| Generate TLS certificate | Helm (cert-manager) | Kubernetes resource |
| Store secret in Vault | Ansible | Operational task |
| Configure /etc/hosts | Ansible | System configuration |
| Deploy Prometheus | Helm | Kubernetes application |
| Create Cloudflare Tunnel | Terraform | Infrastructure provisioning |
| Configure Tunnel ingress rules | Terraform | Part of tunnel infrastructure |
| Bootstrap FluxCD | Ansible | Operational task |
| Configure cert-manager issuer | Helm | Kubernetes resource |

## Migration History

### TLS Certificates
- **Before**: Terraform generated TLS certificates (CSR, private keys)
- **After**: cert-manager via Helm charts manages TLS certificates
- **Reason**: cert-manager is the standard Kubernetes way to manage TLS

### DNS Configuration
- **Before**: Shell scripts managed /etc/hosts
- **After**: Ansible playbook (`configure-dns.yml`)
- **Reason**: Better automation and idempotency

### Secret Management
- **Before**: Shell scripts with kubectl commands
- **After**: Ansible playbook (`manage-secrets.yml`)
- **Reason**: Declarative, idempotent secret management

### Tunnel Configuration
- **Status**: Managed via Terraform (Cloudflare API)
- **Reason**: Tunnel ingress rules are infrastructure provisioning, not application config
- **Note**: Tunnel connector pod is deployed via Kubernetes (FluxCD), but configuration is via Cloudflare API

## Best Practices

1. **Use Ansible for**:
   - Anything that touches the host system
   - Operational tasks (secrets, DNS)
   - Idempotent configuration management

2. **Use Terraform for**:
   - Cloud provider resources (DNS, Tunnels)
   - Infrastructure state management
   - Resources that need to be tracked in state

3. **Use Helm for**:
   - Kubernetes resources
   - Application configuration
   - TLS certificate management (via cert-manager)
   - Reusable component packaging

4. **Avoid Mixing**:
   - Don't use Terraform for Kubernetes resources (use Helm/FluxCD)
   - Don't use Ansible for Cloud provider resources (use Terraform)
   - Don't use Helm for system configuration (use Ansible)

## Examples

### Adding a New Service

1. **DNS Configuration** (Ansible):
   ```bash
   ansible-playbook ansible/playbooks/configure-dns.yml \
     -e configure_hosts_file=true
   ```

2. **Cloudflare DNS Record** (Terraform):
   ```hcl
   resource "cloudflare_record" "new_service" {
     zone_id = data.cloudflare_zone.eldertree_xyz[0].id
     name    = "new-service"
     content = var.public_ip
     type    = "A"
   }
   ```

3. **TLS Certificate** (Helm/cert-manager):
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     annotations:
       cert-manager.io/cluster-issuer: selfsigned-cluster-issuer
   spec:
     tls:
       - hosts:
           - new-service.eldertree.local
         secretName: new-service-tls
   ```

4. **Kubernetes Deployment** (Helm/FluxCD):
   ```yaml
   # Deploy via HelmRelease or Kustomization
   ```

## Troubleshooting

### "Where is X configured?"
- **System config**: Check `ansible/playbooks/`
- **Infrastructure**: Check `terraform/`
- **Kubernetes**: Check `helm/` or `clusters/eldertree/`

### "Should I use Ansible, Terraform, or Helm?"
- **System/host level**: Ansible
- **Cloud provider**: Terraform
- **Kubernetes**: Helm

### "How do I update X?"
- **System config**: Update Ansible playbook, run playbook
- **Infrastructure**: Update Terraform, run `terraform apply`
- **Kubernetes**: Update Helm chart or Kustomization, FluxCD syncs automatically

