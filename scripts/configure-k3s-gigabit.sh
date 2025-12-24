#!/bin/bash
# Configure k3s to use gigabit network
# This script modifies k3s service files to use eth0 with gigabit IPs

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Configuring k3s to use gigabit network${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Check KUBECONFIG
if [ -z "${KUBECONFIG:-}" ]; then
    if [ -f ~/.kube/config-eldertree ]; then
        export KUBECONFIG=~/.kube/config-eldertree
        echo -e "${YELLOW}Using KUBECONFIG=~/.kube/config-eldertree${NC}"
    else
        echo -e "${RED}Error: KUBECONFIG not set and ~/.kube/config-eldertree not found${NC}"
        exit 1
    fi
fi

# Gigabit IPs
NODE_0_IP="10.0.0.1"
NODE_1_IP="10.0.0.2"
INTERFACE="eth0"

# Function to configure a node
configure_node() {
    local node_name=$1
    local gigabit_ip=$2
    local is_control_plane=$3
    
    echo -e "\n${GREEN}Configuring ${node_name} with IP ${gigabit_ip}${NC}"
    
    # Check if node exists
    if ! kubectl get node "$node_name" &>/dev/null; then
        echo -e "${RED}Node ${node_name} not found${NC}"
        return 1
    fi
    
    # Determine service file
    local service_file="/etc/systemd/system/k3s.service"
    local service_name="k3s"
    if [ "$is_control_plane" = "false" ]; then
        service_file="/etc/systemd/system/k3s-agent.service"
        service_name="k3s-agent"
    fi
    
    # Create a script to run on the node
    local script=$(cat <<EOF
#!/bin/bash
set -e

SERVICE_FILE="${service_file}"
SERVICE_NAME="${service_name}"
GIGABIT_IP="${gigabit_ip}"
INTERFACE="${INTERFACE}"

# Backup service file
if [ -f "\$SERVICE_FILE" ]; then
    cp "\$SERVICE_FILE" "\${SERVICE_FILE}.backup-\$(date +%s)"
    echo "Backed up service file"
fi

# Check if already configured
if grep -q "node-ip=\${GIGABIT_IP}" "\$SERVICE_FILE" 2>/dev/null; then
    echo "Already configured with node-ip=\${GIGABIT_IP}"
    exit 0
fi

# Update ExecStart line
sed -i "s|^ExecStart=\(.*\)|ExecStart=\1 --node-ip=\${GIGABIT_IP} --flannel-iface=\${INTERFACE}|" "\$SERVICE_FILE"

echo "Updated service file with --node-ip=\${GIGABIT_IP} --flannel-iface=\${INTERFACE}"

# Reload systemd
systemctl daemon-reload

# Restart service
systemctl restart "\$SERVICE_NAME"

echo "Service restarted"
EOF
)
    
    # Execute script on node
    echo -e "${YELLOW}Updating ${service_file} on ${node_name}...${NC}"
    kubectl debug node/"$node_name" -it --image=busybox --restart=Never -- sh -c "$script" 2>&1 || {
        echo -e "${YELLOW}Trying alternative method...${NC}"
        # Alternative: use a Job
        kubectl run "configure-k3s-${node_name}-$(date +%s)" \
            --image=busybox \
            --restart=Never \
            --overrides="{\"spec\":{\"nodeName\":\"${node_name}\",\"hostNetwork\":true,\"hostPID\":true,\"containers\":[{\"name\":\"configure\",\"image\":\"busybox\",\"command\":[\"sh\",\"-c\",\"${script//\"/\\\"}\"],\"securityContext\":{\"privileged\":true},\"volumeMounts\":[{\"name\":\"systemd\",\"mountPath\":\"/etc/systemd\"},{\"name\":\"run\",\"mountPath\":\"/run\"}]}],\"volumes\":[{\"name\":\"systemd\",\"hostPath\":{\"path\":\"/etc/systemd\"}},{\"name\":\"run\",\"hostPath\":{\"path\":\"/run\"}}]}}" \
            --rm -i --attach 2>&1 || echo -e "${RED}Failed to configure ${node_name}${NC}"
    }
}

# Configure nodes
configure_node "node-0" "$NODE_0_IP" "true"
configure_node "node-1" "$NODE_1_IP" "false"

echo -e "\n${GREEN}✅ Configuration complete!${NC}"
echo -e "${YELLOW}Waiting for nodes to be ready...${NC}"
sleep 10

# Verify
kubectl get nodes -o wide

echo -e "\n${GREEN}Verify nodes are using gigabit IPs:${NC}"
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'

