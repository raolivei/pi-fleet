# =============================================================================
# K3s Control Plane Installation on Raspberry Pi
# =============================================================================

# Generate a random token if not provided
# Only create if k3s resources are not skipped (not CI)
resource "random_password" "k3s_token" {
  count   = var.skip_k3s_resources ? 0 : 1
  length  = 64
  special = false
}

locals {
  # Handle sensitive k3s_token: completely avoid evaluating sensitive values in CI
  # In CI (skip_k3s_resources=true), use placeholder without touching sensitive vars
  # When not in CI, use coalesce to handle null k3s_token safely
  # Wrap everything in try() to avoid crashes from sensitive value comparisons
  k3s_token = var.skip_k3s_resources ? "ci-placeholder-token" : try(
    coalesce(
      try(var.k3s_token, null),
      try(random_password.k3s_token[0].result, null)
    ),
    "placeholder"
  )
  k3s_version_flag = var.k3s_version != "" ? "INSTALL_K3S_VERSION=${var.k3s_version}" : ""
  kubeconfig_path  = pathexpand(var.kubeconfig_path)
}

# =============================================================================
# Step 1: Configure system prerequisites
# =============================================================================

resource "null_resource" "system_prep" {
  count = var.skip_k3s_resources ? 0 : 1 # Skip in CI

  connection {
    type     = "ssh"
    host     = coalesce(var.pi_host, "eldertree")
    user     = coalesce(var.pi_user, "raolivei")
    password = var.pi_password
    timeout  = "5m"
  }

  # Verify hostname
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Current hostname: '$(hostname)",
      "echo 'Verifying we are on ${coalesce(var.pi_host, "eldertree")}...'",
    ]
  }

  # System prerequisites
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Installing prerequisites...'",
      "echo ${var.pi_password} | sudo -S apt-get update -qq",
      "echo ${var.pi_password} | sudo -S apt-get install -y -qq curl iptables",
      "echo 'Enabling cgroups for containers...'",
      "echo ${var.pi_password} | sudo -S sed -i 's/$/ cgroup_memory=1 cgroup_enable=memory/' /boot/firmware/cmdline.txt 2>/dev/null || true",
    ]
  }
}

# =============================================================================
# Step 2: Install K3s as control plane with cluster-init
# =============================================================================

resource "null_resource" "install_k3s" {
  count      = var.skip_k3s_resources ? 0 : 1 # Skip in CI
  depends_on = [null_resource.system_prep]

  connection {
    type     = "ssh"
    host     = coalesce(var.pi_host, "eldertree")
    user     = coalesce(var.pi_user, "raolivei")
    password = var.pi_password
    timeout  = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Installing K3s control plane...'",
      "curl -sfL https://get.k3s.io | ${local.k3s_version_flag} K3S_TOKEN='${local.k3s_token}' sh -s - server --cluster-init --write-kubeconfig-mode=644 --tls-san=${coalesce(var.pi_host, "eldertree")}",
      "echo 'Waiting for K3s to be ready...'",
      "until echo ${var.pi_password} | sudo -S k3s kubectl get nodes 2>/dev/null; do sleep 5; done",
      "echo 'K3s installation complete!'",
      "echo ${var.pi_password} | sudo -S k3s kubectl get nodes",
    ]
  }

  # Save the node token for future worker joins
  provisioner "remote-exec" {
    inline = [
      "echo ${var.pi_password} | sudo -S cat /var/lib/rancher/k3s/server/node-token",
    ]
  }
}

# =============================================================================
# Step 3: Install k9s
# =============================================================================

resource "null_resource" "install_k9s" {
  count      = var.skip_k3s_resources ? 0 : 1 # Skip in CI
  depends_on = [null_resource.install_k3s]

  connection {
    type     = "ssh"
    host     = coalesce(var.pi_host, "eldertree")
    user     = coalesce(var.pi_user, "raolivei")
    password = var.pi_password
    timeout  = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Installing k9s...'",
      "K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep 'tag_name' | awk '{print $2}' | tr -d '\",' | sed 's/^v//')",
      "curl -sfL https://github.com/derailed/k9s/releases/download/v$${K9S_VERSION}/k9s_Linux_arm64.tar.gz -o /tmp/k9s.tar.gz",
      "echo ${var.pi_password} | sudo -S tar -xzf /tmp/k9s.tar.gz -C /tmp",
      "echo ${var.pi_password} | sudo -S mv /tmp/k9s /usr/local/bin/k9s",
      "echo ${var.pi_password} | sudo -S chmod +x /usr/local/bin/k9s",
      "rm -f /tmp/k9s.tar.gz",
      "echo 'k9s installation complete!'",
      "k9s version",
    ]
  }
}

# =============================================================================
# Step 4: Retrieve kubeconfig and node token
# =============================================================================

resource "null_resource" "retrieve_kubeconfig" {
  count      = var.skip_k3s_resources ? 0 : 1 # Skip in CI
  depends_on = [null_resource.install_k3s]

  # Download kubeconfig
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p $(dirname ${local.kubeconfig_path})
      sshpass -p '${var.pi_password}' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${coalesce(var.pi_user, "raolivei")}@${coalesce(var.pi_host, "eldertree")} 'sudo cat /etc/rancher/k3s/k3s.yaml' > ${local.kubeconfig_path}
      sed -i.bak 's/127.0.0.1/${coalesce(var.pi_host, "eldertree")}/g' ${local.kubeconfig_path}
      chmod 600 ${local.kubeconfig_path}
      rm -f ${local.kubeconfig_path}.bak
      # Update cluster and context names to eldertree
      ${path.module}/update-kubeconfig.sh ${local.kubeconfig_path}
    EOT
  }

  # Download node token for future worker nodes
  provisioner "local-exec" {
    command = <<-EOT
      sshpass -p '${var.pi_password}' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${coalesce(var.pi_user, "raolivei")}@${coalesce(var.pi_host, "eldertree")} 'echo ${var.pi_password} | sudo -S cat /var/lib/rancher/k3s/server/node-token' > ${path.module}/k3s-node-token
      chmod 600 ${path.module}/k3s-node-token
    EOT
  }
}
