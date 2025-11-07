output "cluster_endpoint" {
  description = "K3s cluster API endpoint"
  value       = "https://${var.pi_host}:6443"
}

output "kubeconfig_location" {
  description = "Path to the downloaded kubeconfig file"
  value       = pathexpand(var.kubeconfig_path)
}

output "node_token_location" {
  description = "Path to the saved node token file"
  value       = "${path.module}/k3s-node-token"
}

output "ssh_command" {
  description = "SSH command to connect to the control plane"
  value       = "ssh ${var.pi_user}@${var.pi_host}"
}

output "next_steps" {
  description = "Next steps to use your cluster"
  value = <<-EOT
    
    ╔══════════════════════════════════════════════════════════╗
    ║         K3s Control Plane Installation Complete!         ║
    ╚══════════════════════════════════════════════════════════╝
    
    1. Set your kubeconfig:
       export KUBECONFIG=${pathexpand(var.kubeconfig_path)}
    
    2. Verify cluster status:
       kubectl get nodes
       kubectl get pods -A
    
    3. To add worker nodes, use the token saved at:
       ${path.module}/k3s-node-token
    
    4. SSH to control plane:
       ssh ${var.pi_user}@${var.pi_host}
    
    5. Access the cluster from other machines by updating their
       /etc/hosts with the Pi's IP address for ${var.pi_host}
    
  EOT
}

