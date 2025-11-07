# =============================================================================
# K3s Control Plane Installation on Raspberry Pi
# =============================================================================

# Generate a random token if not provided
resource "random_password" "k3s_token" {
  length  = 64
  special = false
}

locals {
  k3s_token        = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token.result
  k3s_version_flag = var.k3s_version != "" ? "INSTALL_K3S_VERSION=${var.k3s_version}" : ""
  kubeconfig_path  = pathexpand(var.kubeconfig_path)
}

# =============================================================================
# Step 1: Configure system prerequisites
# =============================================================================

resource "null_resource" "system_prep" {
  connection {
    type     = "ssh"
    host     = var.pi_host
    user     = var.pi_user
    password = var.pi_password
    timeout  = "5m"
  }

  # Verify hostname
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Current hostname: '$(hostname)",
      "echo 'Verifying we are on ${var.pi_host}...'",
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
  depends_on = [null_resource.system_prep]

  connection {
    type     = "ssh"
    host     = var.pi_host
    user     = var.pi_user
    password = var.pi_password
    timeout  = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Installing K3s control plane...'",
      "curl -sfL https://get.k3s.io | ${local.k3s_version_flag} K3S_TOKEN='${local.k3s_token}' sh -s - server --cluster-init --write-kubeconfig-mode=644 --tls-san=${var.pi_host}",
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
# Step 3: Retrieve kubeconfig and node token
# =============================================================================

resource "null_resource" "retrieve_kubeconfig" {
  depends_on = [null_resource.install_k3s]

  # Download kubeconfig
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p $(dirname ${local.kubeconfig_path})
      sshpass -p '${var.pi_password}' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${var.pi_user}@${var.pi_host} 'sudo cat /etc/rancher/k3s/k3s.yaml' > ${local.kubeconfig_path}
      sed -i.bak 's/127.0.0.1/${var.pi_host}/g' ${local.kubeconfig_path}
      chmod 600 ${local.kubeconfig_path}
      rm -f ${local.kubeconfig_path}.bak
    EOT
  }

  # Download node token for future worker nodes
  provisioner "local-exec" {
    command = <<-EOT
      sshpass -p '${var.pi_password}' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${var.pi_user}@${var.pi_host} 'echo ${var.pi_password} | sudo -S cat /var/lib/rancher/k3s/server/node-token' > ${path.module}/k3s-node-token
      chmod 600 ${path.module}/k3s-node-token
    EOT
  }
}
