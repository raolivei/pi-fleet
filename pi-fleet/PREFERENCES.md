# Project Preferences & Context

This file documents important preferences and context for working on this project.

## Git Workflow

- **Always create feature branches** (`feat/`, `fix/`, `chore/`, `docs/`, `infra/`, `test/`)
- **Never commit directly to main or dev**
- Keep feature branches until work is complete, tested, and stable
- Only merge to main when production-ready
- See [CONTRIBUTING.md](CONTRIBUTING.md) for full workflow details

## Pi Fleet Naming Convention

- **Control plane**: `eldertree`
- **Worker nodes**: `fleet-worker-01`, `fleet-worker-02`, etc.
- **Cluster endpoint**: `https://eldertree:6443`
- **Kubeconfig**: `~/.kube/config-eldertree`
- **Node token**: `terraform/k3s-node-token`

## Raspberry Pi Credentials

- **Hostname**: `eldertree`
- **SSH user**: `raolivei`
- **SSH password**: `Control01!`
- **SSH command**: `ssh raolivei@eldertree`
- **Hardware**: Raspberry Pi 5 (8GB RAM, ARM64)
- **OS**: Debian 12 Bookworm

## Documentation Style

- **Preference**: Concise, simple, and brief
- Don't overload with verbose documentation
- Keep communication simple and to-the-point
- Documentation should be practical, not exhaustive

## Infrastructure Tools

- **Use Terraform** for infrastructure automation
- **NOT Ansible** - prefer pure Terraform
- Use `null_resource` with `remote-exec` provisioners for SSH-based provisioning
- Keep infrastructure code simple and direct

## Repository Structure

- **Main branch**: Production-ready code only
- **Feature branches**: Work in progress (e.g., `infra/pi-fleet`)
- **Current active branch**: `infra/pi-fleet` (infrastructure setup)

---

*This file serves as a reference for AI assistants and contributors working on this project.*

