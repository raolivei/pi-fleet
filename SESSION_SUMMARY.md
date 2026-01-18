# Session Summary: Node-2 Setup and Playbook Improvements

## Context

Setting up node-2 in the eldertree k3s cluster and improving the Ansible playbooks for future node setups.

## Key Accomplishments

### 1. Fixed Recursive Loop in k3s Token Variable

**Problem**: `k3s_token: "{{ k3s_token }}"` caused "maximum recursion depth exceeded" error.

**Solution**:

- Renamed input variable to `k3s_token_override` to avoid recursion
- Token retrieval from node-1 sets `k3s_token_retrieved` fact
- New play determines final token (`k3s_token_final`) from override or retrieved value
- Passes `k3s_token_final` to `install-k3s-worker.yml`

**Files Changed**: `ansible/playbooks/setup-new-node.yml`

### 2. Fixed IP Extraction Logic

**Problem**: IP extraction was getting dictionary keys (`['address', 'broadcast', 'netmask', 'network', 'prefix']`) instead of actual IP addresses.

**Solution**:

- Simplified from ~24 lines of nested Jinja2 loops to ~8 lines using Ansible filters
- Uses `selectattr` and `map` filters instead of manual loops
- Handles both dict and list cases elegantly
- Much more readable and maintainable

**Files Changed**: `ansible/playbooks/setup-new-node.yml` (lines 114-137, 142-180)

### 3. Added Automatic IP Address Calculation

**Problem**: User had to manually specify `wlan0_ip` and `eth0_ip` every time.

**Solution**:

- Added pre-task that reads existing nodes from inventory
- Calculates next wlan0 IP (descending from 192.168.2.86: 86, 85, 84, 83...)
- Calculates next eth0 IP (ascending from 10.0.0.1: 1, 2, 3, 4...)
- Can still be overridden with `-e wlan0_ip=... -e eth0_ip=...`

**New Usage**:

```bash
# Simple - IPs calculated automatically
ansible-playbook playbooks/setup-new-node.yml --limit node-2

# With overrides (if needed)
ansible-playbook playbooks/setup-new-node.yml --limit node-2 \
  -e "wlan0_ip=192.168.2.84" -e "eth0_ip=10.0.0.3"
```

**Files Changed**: `ansible/playbooks/setup-new-node.yml`

### 4. NetworkManager IP Verification Improvements

**Problem**: NetworkManager delays caused false failures when checking eth0 IP assignment.

**Solution**:

- Added retry logic (up to 10 times, 2 seconds apart) for initial IP assignment
- Additional retries if correct IP not found initially
- Improved error messages with troubleshooting hints

**Files Changed**: `ansible/playbooks/setup-new-node.yml`

### 5. Password Management Discussion

**Question**: How to pass passwords to Ansible without being prompted every time?

**Options Discussed**:

1. **Ansible Vault** (recommended) - Encrypt passwords in vault files
2. **Environment Variables** - Set `PI_PASSWORD` or `env_target_password`
3. **1Password Integration** - Use 1Password CLI to retrieve passwords dynamically

**Current State**: Playbooks already support:

- `vault_target_password` from Ansible Vault
- `PI_PASSWORD` or `env_target_password` environment variables
- Example vault file exists at: `ansible/group_vars/raspberry_pi/vault.yml.example`

## Current Inventory State

```yaml
node-1: 192.168.2.86 (wlan0), 10.0.0.1 (eth0)
node-1: 192.168.2.85 (wlan0), 10.0.0.2 (eth0)
node-2: 192.168.2.84 (wlan0), 10.0.0.3 (eth0)
```

## IP Calculation Logic

### wlan0 (Management Network)

- Base IP: `192.168.2.86` (node-1)
- Pattern: Descending (86, 85, 84, 83...)
- Calculation: `base_ip - (number_of_existing_nodes)`

### eth0 (Gigabit Network)

- Base IP: `10.0.0.1` (node-1)
- Pattern: Ascending (1, 2, 3, 4...)
- Calculation: `max(existing_eth0_ips) + 1`

## Files Modified

1. **`ansible/playbooks/setup-new-node.yml`**
   - Fixed recursive k3s_token variable
   - Simplified IP extraction logic
   - Added automatic IP calculation
   - Improved NetworkManager retry logic
   - Updated documentation

## Git Commits Made

1. `fix: simplify eth0 IP verification to avoid template errors`
2. `fix: correctly extract IP from dict structure in ansible_facts`
3. `fix: correct boolean type for add_local_key variable`
4. `fix: correct YAML structure for playbook imports`
5. `fix: resolve recursive loop in k3s_token variable`
6. `docs: update variable name in comments (k3s_token -> k3s_token_override)`
7. `refactor: simplify IP extraction using Ansible filters`
8. `feat: automatically calculate next available IP addresses`
9. `docs: update usage examples to show automatic IP calculation`

## Next Steps / Remaining Work

1. **Test the automatic IP calculation** - Verify it works correctly for new nodes
2. **Set up 1Password integration** (if desired) - Create vault password script using 1Password CLI
3. **Continue node-2 setup** - Run the playbook with automatic IPs:
   ```bash
   ansible-playbook playbooks/setup-new-node.yml --limit node-2
   ```

## Important Notes

- The playbook now automatically calculates IPs based on existing nodes in inventory
- k3s token is automatically retrieved from node-1 if not provided
- All changes are committed and pushed to branch: `fix/pi-hole-servicelb-annotation`
- The playbook is idempotent and can be run multiple times safely

## Branch Information

- Current branch: `fix/pi-hole-servicelb-annotation`
- All changes committed and pushed
- Ready for testing or merging








