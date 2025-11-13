variable "pi_host" {
  description = "Hostname or IP address of the Raspberry Pi"
  type        = string
  default     = "eldertree"
}

variable "pi_user" {
  description = "SSH username for the Raspberry Pi"
  type        = string
  default     = "raolivei"
}

variable "pi_password" {
  description = "SSH password for the Raspberry Pi"
  type        = string
  sensitive   = true
}

variable "k3s_version" {
  description = "Version of k3s to install (leave empty for latest)"
  type        = string
  default     = ""
}

variable "k3s_token" {
  description = "K3s cluster token (auto-generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "kubeconfig_path" {
  description = "Local path to save the kubeconfig"
  type        = string
  default     = "~/.kube/config-eldertree"
}

