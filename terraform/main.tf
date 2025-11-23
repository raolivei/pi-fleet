# =============================================================================
# Terraform Infrastructure Resources
# =============================================================================
#
# NOTE: k3s installation is handled by Ansible (ansible/playbooks/install-k3s.yml)
# Terraform is used only for infrastructure resources:
# - Cloudflare DNS records
# - Cloudflare Tunnel
# - TLS certificates
#
# See cloudflare.tf for Cloudflare resources.
#
# For k3s installation, use:
#   ansible-playbook ansible/playbooks/install-k3s.yml --ask-pass --ask-become-pass
#
