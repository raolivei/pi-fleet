# Adding a New Node to Eldertree Cluster

Complete guide for adding a new Raspberry Pi node (e.g., node-2) to the eldertree k3s cluster.

## Prerequisites

- New Raspberry Pi 5 with NVMe drive attached
- SD card with backup OS (for initial setup)
- Physical access to the node (for initial configuration)
- Access to existing cluster nodes via SSH/Ansible
- kubectl configured with cluster access

## Overview

The process involves:
1. **NVMe Boot Setup** - Configure node to boot from NVMe
2. **System Configuration** - Hostname, network, user setup
3. **Gigabit Network** - Configure eth0 with cluster IP
4. **SSH Access** - Set up SSH keys for Ansible management
5. **k3s Worker Installation** - Join node to cluster
6. **Flannel Configuration** - Ensure gigabit network is used

## Step 1: NVMe Boot Setup

### 1.1 Initial Boot from SD Card

1. **Insert SD card** with backup OS into the Raspberry Pi
2. **Boot the node** - It will boot as `node-x` (default hostname)
3. **Verify network connectivity** - Node should get DHCP IP on wlan0

### 1.2 Clone OS to NVMe

Use the existing NVMe setup script or Ansible playbook:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet

# Option A: Use Ansible playbook (recommended)
ansible-playbook ansible/playbooks/setup-nvme-storage.yml \
  --limit <node-ip-or-hostname> \
  --ask-pass --ask-become-pass

# Option B: Use shell script (if playbook not available)
ansible <node-ip-or-hostname> -i "ip," -m script \
  -a "scripts/storage/setup-nvme-boot.sh" \
  --become --ask-pass
```

### 1.3 Fix NVMe Boot Configuration

After cloning, ensure boot configuration is correct:

```bash
ansible-playbook ansible/playbooks/fix-nvme-boot.yml \
  --limit <node-ip-or-hostname> \
  --ask-pass --ask-become-pass
```

### 1.4 Reboot and Verify NVMe Boot

1. **Remove SD card** from the node
2. **Reboot** the node
3. **Verify** it boots from NVMe:
   ```bash
   # After node comes back online
   ansible <node-ip> -i "ip," -m shell \
     -a "mount | grep nvme" --become --ask-pass
   ```

## Step 2: System Configuration

### 2.1 Set Hostname and Management IP

Configure hostname and static management IP (wlan0):

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet

# For node-2, use IP 192.168.2.87 (increment from node-1's 192.168.2.85)
ansible-playbook ansible/playbooks/setup-system.yml \
  --limit <node-ip> \
  -e "hostname=node-2.eldertree.local" \
  -e "static_ip=192.168.2.87" \
  --ask-pass --ask-become-pass
```

**IP Assignment Reference:**
- node-1: `192.168.2.86` (eldertree.local)
- node-1: `192.168.2.85`
- node-2: `192.168.2.87` (next available)
- node-3: `192.168.2.88` (future)

### 2.2 Reboot and Verify

```bash
ansible <node-ip> -i "ip," -m reboot --become --ask-pass

# Wait for reboot, then verify
ansible node-2.eldertree.local -i ansible/inventory/hosts.yml \
  -m shell -a "hostname && ip addr show wlan0 | grep 'inet '" \
  --become
```

## Step 3: Configure Gigabit Network

### 3.1 Add Gigabit IP to eth0

Configure eth0 with cluster IP using NetworkManager (matching node-1 and node-1):

```bash
# Connect to node
ansible node-2.eldertree.local -i ansible/inventory/hosts.yml \
  -m shell -a "sudo nmcli connection modify eth0 ipv4.addresses 10.0.0.3/24 ipv4.method manual && sudo nmcli connection up eth0" \
  --become

# Verify
ansible node-2.eldertree.local -i ansible/inventory/hosts.yml \
  -m shell -a "ip addr show eth0 | grep 'inet '" --become
```

**Gigabit IP Assignment:**
- node-1: `10.0.0.1`
- node-1: `10.0.0.2`
- node-2: `10.0.0.3`
- node-3: `10.0.0.4` (future)

### 3.2 Verify Network Configuration

```bash
ansible node-2.eldertree.local -i ansible/inventory/hosts.yml \
  -m shell -a "ip addr show eth0 && echo '---' && ip addr show wlan0" \
  --become
```

Should show:
- eth0: `10.0.0.3/24` (gigabit cluster network)
- wlan0: `192.168.2.87/24` (management network)

## Step 4: Set Up SSH Access for Ansible

### 4.1 Add Node to Ansible Inventory

Edit `ansible/inventory/hosts.yml`:

```yaml
---
all:
  children:
    raspberry_pi:
      hosts:
        node-1:
          ansible_host: 192.168.2.86
          ansible_user: raolivei
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519_raolivei
          ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
          ansible_python_interpreter: /usr/bin/python3
          poe_hat_enabled: true
        node-1:
          ansible_host: 192.168.2.85
          ansible_user: raolivei
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519_raolivei
          ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
          ansible_python_interpreter: /usr/bin/python3
          poe_hat_enabled: true
        node-2:
          ansible_host: 192.168.2.87
          ansible_user: raolivei
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519_raolivei
          ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
          ansible_python_interpreter: /usr/bin/python3
          poe_hat_enabled: true
```

### 4.2 Add SSH Key Using kubectl

Since the node isn't accessible via SSH yet, use kubectl to add your SSH key:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet
export KUBECONFIG=~/.kube/config-eldertree

# Get your RSA public key (already in ssh-agent, no passphrase needed)
RSA_KEY=$(cat ~/.ssh/id_rsa.pub)

# Use kubectl to add SSH key to node-2
kubectl run ssh-key-setup-node2 \
  --image=busybox \
  --restart=Never \
  --overrides="{\"spec\":{\"hostNetwork\":true,\"containers\":[{\"name\":\"ssh-key-setup\",\"image\":\"busybox\",\"command\":[\"sh\",\"-c\",\"mkdir -p /host/home/raolivei/.ssh && chmod 700 /host/home/raolivei/.ssh && echo '$RSA_KEY' >> /host/home/raolivei/.ssh/authorized_keys && chmod 600 /host/home/raolivei/.ssh/authorized_keys && cat /host/home/raolivei/.ssh/authorized_keys\"],\"volumeMounts\":[{\"name\":\"host-root\",\"mountPath\":\"/host\",\"readOnly\":false}],\"securityContext\":{\"privileged\":true}}],\"volumes\":[{\"name\":\"host-root\",\"hostPath\":{\"path\":\"/\"}}],\"nodeSelector\":{\"kubernetes.io/hostname\":\"node-2.eldertree.local\"}}}" \
  --rm -i
```

**Note:** This requires the node to already be in the cluster. If node-2 isn't in the cluster yet, you'll need to:
1. Use physical access to add the key manually, OR
2. Use password authentication temporarily, OR
3. Copy the key from node-1/node-1

**Alternative: Manual SSH Key Setup (if node not in cluster yet)**

If node-2 isn't in the cluster yet, use physical access:

```bash
# On your Mac, copy the key
cat ~/.ssh/id_rsa.pub

# On node-2 (via keyboard/monitor or temporary password SSH):
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDU3YWV7..." >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 4.3 Verify SSH Access

```bash
# Test SSH connection
ssh raolivei@192.168.2.87 "echo 'SSH works!' && hostname"

# Test Ansible access
ansible node-2 -i ansible/inventory/hosts.yml -m ping
```

## Step 5: Install k3s Worker

### 5.1 Get k3s Token from Control Plane

```bash
# On node-1 (control plane)
ansible node-1 -i ansible/inventory/hosts.yml \
  -m shell -a "sudo cat /var/lib/rancher/k3s/server/node-token" \
  --become
```

Save this token - you'll need it for node-2.

### 5.2 Install k3s Agent

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet

# Install k3s worker
ansible-playbook ansible/playbooks/install-k3s.yml \
  --limit node-2 \
  -e "k3s_mode=agent" \
  -e "k3s_token=<token-from-step-5.1>" \
  -e "k3s_server_url=https://node-1.eldertree.local:6443" \
  --become
```

Or use the worker-specific playbook if available:

```bash
ansible-playbook ansible/playbooks/install-k3s-worker.yml \
  --limit node-2 \
  -e "k3s_token=<token-from-step-5.1>" \
  -e "k3s_server_url=https://node-1.eldertree.local:6443" \
  --become
```

### 5.3 Verify Node Joined Cluster

```bash
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes -o wide
```

Should show node-2 with status `Ready` and InternalIP `10.0.0.3`.

## Step 6: Configure Flannel for Gigabit Network

### 6.1 Update k3s-agent Service File

Configure k3s-agent to use gigabit network:

```bash
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "sudo tee /etc/systemd/system/k3s-agent.service > /dev/null << 'EOF'
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
Wants=network-online.target
After=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
EnvironmentFile=-/etc/systemd/system/k3s-agent.service.env
KillMode=process
Delegate=yes
User=root
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/k3s \\
    agent \\
	'--node-ip=10.0.0.3' \\
	'--flannel-iface=eth0'
EOF
sudo systemctl daemon-reload && sudo systemctl restart k3s-agent" \
  --become
```

**CRITICAL:** 
- Flags must be in single quotes: `'--node-ip=10.0.0.3'`
- Last line must NOT have trailing backslash
- Use tabs for indentation

### 6.2 Update Flannel Public IP Annotation

```bash
export KUBECONFIG=~/.kube/config-eldertree

kubectl annotate node node-2.eldertree.local \
  flannel.alpha.coreos.com/public-ip=10.0.0.3 \
  --overwrite
```

### 6.3 Restart k3s-agent and Verify

```bash
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "sudo systemctl stop k3s-agent && sudo ip link delete flannel.1 2>/dev/null; sudo rm -rf /var/lib/rancher/k3s/agent/etc/flannel 2>/dev/null; sudo systemctl start k3s-agent && sleep 30 && ip -d link show flannel.1 | grep -E 'local|dev'" \
  --become
```

Should show: `local 10.0.0.3 dev eth0`

### 6.4 Verify Flannel Configuration

```bash
# Check flannel interface
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "ip -d link show flannel.1 | grep -E 'local|dev'" \
  --become

# Check flannel routes
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "ip route show | grep flannel" \
  --become

# Check logs
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "sudo journalctl -u k3s-agent --since '2 minutes ago' | grep -i 'interface.*flannel\|will be used'" \
  --become
```

Should show: "The interface eth0 with ipv4 address 10.0.0.3 will be used by flannel"

## Step 7: Final Verification

### 7.1 Cluster Status

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Check all nodes
kubectl get nodes -o wide

# Verify node-2 details
kubectl get node node-2.eldertree.local -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}'
# Should output: 10.0.0.3
```

### 7.2 Network Connectivity

```bash
# Test node-to-node connectivity
ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "ping -c 3 10.0.0.1 -I eth0" \
  --become

ansible node-2 -i ansible/inventory/hosts.yml \
  -m shell -a "ping -c 3 10.0.0.2 -I eth0" \
  --become
```

### 7.3 Pod-to-Pod Communication

```bash
export KUBECONFIG=~/.kube/config-eldertree

# Get a pod IP from another node
kubectl get pods -A -o wide | grep node-1 | head -1

# Test from node-2 pod
kubectl run test-pod-node2 \
  --image=busybox \
  --restart=Never \
  --overrides='{"spec":{"nodeName":"node-2.eldertree.local"}}' \
  --rm -i -- sh -c "ping -c 3 <pod-ip-from-node-1>"
```

## Troubleshooting

### SSH Access Issues

If SSH key setup fails:
1. Verify node is in cluster (for kubectl method)
2. Use physical access to add key manually
3. Check `/home/raolivei/.ssh/authorized_keys` permissions (700 for .ssh, 600 for authorized_keys)

### Flannel Using Wrong Interface

See [FLANNEL_INTERFACE_CONFIGURATION.md](FLANNEL_INTERFACE_CONFIGURATION.md) for detailed troubleshooting.

Common issues:
- Service file format incorrect (trailing backslashes, missing quotes)
- Flannel public-ip annotation wrong
- Need to restart k3s-agent and clean flannel interface

### Node Not Joining Cluster

1. Check k3s-agent logs:
   ```bash
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "sudo journalctl -u k3s-agent -n 50" \
     --become
   ```

2. Verify connectivity to control plane:
   ```bash
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "ping -c 2 node-1.eldertree.local && curl -k https://node-1.eldertree.local:6443" \
     --become
   ```

3. Check DNS resolution:
   ```bash
   ansible node-2 -i ansible/inventory/hosts.yml \
     -m shell -a "nslookup node-1.eldertree.local" \
     --become
   ```

## IP Address Reference

### Management Network (wlan0)
- node-1: `192.168.2.86` (eldertree.local)
- node-1: `192.168.2.85`
- node-2: `192.168.2.87`
- node-3: `192.168.2.88` (future)

### Gigabit Cluster Network (eth0)
- node-1: `10.0.0.1`
- node-1: `10.0.0.2`
- node-2: `10.0.0.3`
- node-3: `10.0.0.4` (future)

## Related Documentation

- [FLANNEL_INTERFACE_CONFIGURATION.md](FLANNEL_INTERFACE_CONFIGURATION.md) - Flannel interface setup and troubleshooting
- [NVME_STORAGE_SETUP.md](NVME_STORAGE_SETUP.md) - NVMe boot configuration
- [MULTI_NODE_STORAGE.md](MULTI_NODE_STORAGE.md) - Storage configuration for multi-node clusters

