# Ready for Backup - Status Summary

## Current Status

### ✅ node-1 (Ready)
- **Hostname**: `node-1`
- **IP**: `192.168.2.85`
- **Internet**: ✅ Working
- **Backup partition**: ✅ Mounted at `/mnt/backup-nvme` (38GB available)
- **eth0 MAC**: `88:a2:9e:0d:ea:20`

### ⏳ node-0 (eldertree) - Currently Offline
- **Hostname**: `eldertree` / `node-0`
- **IP**: `192.168.2.83`
- **Status**: Needs to be brought online
- **eth0 MAC**: (Get when online)

## What's Ready

1. ✅ **node-1 backup partition** - Created and mounted
2. ✅ **Network configuration** - node-1 working
3. ✅ **Documentation** - Setup guides created

## Next Steps (When node-0 is Online)

### 1. Get node-0 eth0 MAC Address

```bash
ssh raolivei@192.168.2.83 "ip link show eth0 | grep ether | awk '{print \$2}'"
```

### 2. Configure Router DHCP Reservations

**Router Admin**: `192.168.2.1`

Add DHCP reservations:
- node-0 eth0 MAC → `192.168.2.83`
- node-1 eth0 MAC (`88:a2:9e:0d:ea:20`) → `192.168.2.85`

### 3. Verify Gigabit Connectivity

```bash
# From node-0
ping -c 2 192.168.2.85

# From node-1
ping -c 2 192.168.2.83
```

### 4. Start Backup from node-0 to node-1

```bash
cd pi-fleet
./scripts/storage/backup-eldertree-to-node1-nvme.sh
```

Or manually:

```bash
BACKUP_DIR="/mnt/backup-nvme/eldertree-nvme-backup-$(date +%Y%m%d-%H%M%S)"
ssh raolivei@192.168.2.83 "sudo rsync -avh --progress /mnt/nvme/ raolivei@192.168.2.85:$BACKUP_DIR/"
```

## Backup Script Location

- **Script**: `pi-fleet/scripts/storage/backup-eldertree-to-node1-nvme.sh`
- **Destination**: `node-1:/mnt/backup-nvme/eldertree-nvme-backup-YYYYMMDD-HHMMSS/`
- **Method**: rsync over SSH

## Network Configuration Notes

- **DO NOT** configure static IPs with `dhcp4: no` on eth0 (breaks connectivity)
- **USE** router DHCP reservations instead (safe approach)
- See `docs/GIGABIT_NETWORK_SETUP.md` for details

## Verification Checklist

Once node-0 is online:

- [ ] node-0 SSH access works
- [ ] node-0 internet connectivity works
- [ ] Get node-0 eth0 MAC address
- [ ] Configure router DHCP reservations
- [ ] Verify node-to-node connectivity (ping between 192.168.2.83 and 192.168.2.85)
- [ ] Check node-0 NVMe data size: `du -sh /mnt/nvme`
- [ ] Start backup process

