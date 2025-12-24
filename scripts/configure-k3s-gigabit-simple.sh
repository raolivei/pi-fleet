#!/bin/bash
# Simple script to configure k3s via SSH using IP addresses
# This requires SSH access to the nodes

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Configuring k3s to use gigabit network${NC}"

# Node IPs (router network for SSH access)
NODE_0_SSH="192.168.2.86"
NODE_1_SSH="192.168.2.85"
USER="raolivei"

# Gigabit IPs
NODE_0_GIGABIT="10.0.0.1"
NODE_1_GIGABIT="10.0.0.2"
INTERFACE="eth0"

configure_node() {
    local ssh_host=$1
    local gigabit_ip=$2
    local service_name=$3
    
    echo -e "\n${YELLOW}Configuring ${ssh_host}...${NC}"
    
    ssh "${USER}@${ssh_host}" <<EOF
set -e
SERVICE_FILE="/etc/systemd/system/${service_name}.service"
GIGABIT_IP="${gigabit_ip}"
INTERFACE="${INTERFACE}"

# Backup
if [ -f "\$SERVICE_FILE" ]; then
    sudo cp "\$SERVICE_FILE" "\${SERVICE_FILE}.backup-\$(date +%s)"
fi

# Check if already configured
if sudo grep -q "node-ip=\${GIGABIT_IP}" "\$SERVICE_FILE" 2>/dev/null; then
    echo "Already configured"
    exit 0
fi

# Update ExecStart
sudo sed -i "s|^ExecStart=\(.*\)|ExecStart=\1 --node-ip=\${GIGABIT_IP} --flannel-iface=\${INTERFACE}|" "\$SERVICE_FILE"

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart "${service_name}"

echo "✅ Configured ${service_name} with --node-ip=\${GIGABIT_IP} --flannel-iface=\${INTERFACE}"
EOF
}

# Configure nodes
configure_node "$NODE_0_SSH" "$NODE_0_GIGABIT" "k3s"
configure_node "$NODE_1_SSH" "$NODE_1_GIGABIT" "k3s-agent"

echo -e "\n${GREEN}✅ Configuration complete!${NC}"
echo "Waiting 15 seconds for services to restart..."
sleep 15

export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes -o wide

