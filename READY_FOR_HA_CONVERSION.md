# Ready for HA Control Plane Conversion

## Status: Waiting for Node-1 to Come Online

All automation is ready. Once node-1 (192.168.2.101) is accessible, run:

```bash
cd /Users/roliveira/WORKSPACE/raolivei/pi-fleet

# 1. Verify node-1 is up
ssh raolivei@192.168.2.101 "sudo systemctl status k3s"

# 2. Check cluster status
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes

# 3. Remove old node-0 if it exists
kubectl delete node node-0 2>&1 || echo "Node-0 already removed"

# 4. Convert node-2 to control plane
cd ansible
ansible-playbook playbooks/convert-worker-to-control-plane.yml --limit node-2

# 5. Convert node-3 to control plane  
ansible-playbook playbooks/convert-worker-to-control-plane.yml --limit node-3

# 6. Verify HA setup
export KUBECONFIG=~/.kube/config-eldertree
kubectl get nodes -l node-role.kubernetes.io/control-plane
kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane") | "\(.metadata.name): etcd-voter=\(.status.conditions[] | select(.type=="EtcdIsVoter") | .status)"'

# 7. Update kubeconfig for HA
cd ..
./scripts/update-kubeconfig-ha.sh
```

## Files Created/Updated

✅ `ansible/playbooks/convert-worker-to-control-plane.yml` - Automated conversion
✅ `ansible/playbooks/install-k3s.yml` - Updated for HA support
✅ `ansible/playbooks/fix-node-hostname.yml` - Hostname fix playbook
✅ `scripts/update-kubeconfig-ha.sh` - HA kubeconfig management
✅ `docs/CLUSTER_HA_GUIDE.md` - Complete HA documentation
✅ `docs/HA_CONTROL_PLANE_PROGRESS.md` - Progress tracking

All automation is ready to execute once node-1 is back online.
